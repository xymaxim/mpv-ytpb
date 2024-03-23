import atexit
import shutil
from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Self, TypeGuard
from xml.etree import ElementTree

import click
import cloup
import structlog
from cloup.constraints import constraint, require_any
from python_mpv_jsonipc import MPV

from ytpb.actions.compose import compose_dynamic_mpd
from ytpb.cli import base_cli
from ytpb.cli.common import create_playback, query_streams_or_exit, stream_argument
from ytpb.cli.options import cache_options, yt_dlp_option
from ytpb.cli.parameters import FormatSpecParamType, FormatSpecType
from ytpb.locate import SegmentLocator
from ytpb.playback import Playback
from ytpb.segment import SegmentMetadata
from ytpb.streams import Streams
from ytpb.types import SegmentSequence, SetOfStreams, Timestamp
from ytpb.utils.remote import request_reference_sequence

logger = structlog.get_logger(__name__)

YTPB_CLIENT_NAME = "yp"


@dataclass
class TreeNode:
    key: Timestamp
    value: SegmentSequence
    left: Self | None = None
    right: Self | None = None


@dataclass
class TreeMap:
    """A binary search tree implementation to store key-value pairs.

    Keys represent timestamps of segments, while values are sequence numbers.
    """

    root: TreeNode | None = None

    @staticmethod
    def _is_tree_node(node: TreeNode | None) -> TypeGuard[TreeNode]:
        return node is not None

    @staticmethod
    def _insert(
        node: TreeNode | None, key: Timestamp, value: SegmentSequence
    ) -> TreeNode:
        if not TreeMap._is_tree_node(node):
            return TreeNode(key, value, None, None)
        else:
            if key < node.key:
                left = TreeMap._insert(node.left, key, value)
                return TreeNode(node.key, node.value, left, node.right)
            elif key > node.key:
                right = TreeMap._insert(node.right, key, value)
                return TreeNode(node.key, node.value, node.left, right)
            else:
                return TreeNode(node.key, value, node.left, node.right)

    def insert(self, key: Timestamp, value: SegmentSequence) -> None:
        """Insert a pair of timestamp and sequence number into the tree."""
        self.root = TreeMap._insert(self.root, key, value)

    @staticmethod
    def _closest(
        node: TreeNode | None, target: Timestamp, closest: TreeNode
    ) -> TreeNode | None:
        if not TreeMap._is_tree_node(node):
            return closest
        else:
            result = closest
            if abs(target - closest.key) > abs(target - node.key):
                result = node
            if target < node.key:
                return TreeMap._closest(node.left, target, result)
            elif target > node.key:
                return TreeMap._closest(node.right, target, result)
            else:
                return result

    def closest(self, target: Timestamp) -> TreeNode | None:
        """Find the node closest to the target timestamp."""
        if self.root is None:
            return None
        return TreeMap._closest(self.root, target, self.root)


class Listener:
    def __init__(
        self, ipc_server: Path, playback: Playback, streams: SetOfStreams
    ) -> None:
        self._playback = playback
        self._streams = streams
        self._mpd_path: Path | None = None
        self._mpd_start_time: datetime | None = None

        self._mpv = MPV(start_mpv=False, ipc_socket=str(ipc_server))
        self._mpv.bind_event("client-message", self._client_message_handler)

        self.rewind_tree = TreeMap()

    def _client_message_handler(self, event: dict) -> None:
        logger.debug(event)
        try:
            targeted_command, *args = event["args"]
            target, command = targeted_command.split(":")
        except ValueError:
            return
        else:
            if target != YTPB_CLIENT_NAME:
                return

        match command:
            case "rewind":
                try:
                    (rewind_value,) = args
                    self.handle_rewind(datetime.fromisoformat(rewind_value))
                except ValueError:
                    pass

    def _compose_mpd(
        self, rewind_segment_metadata: SegmentMetadata
    ) -> tuple[Path, datetime]:
        mpd = compose_dynamic_mpd(
            self._playback, rewind_segment_metadata, self._streams
        )
        with NamedTemporaryFile(
            "w",
            prefix="ytpb-",
            suffix=".mpd",
            dir=self._playback.get_temp_directory(),
            delete=False,
        ) as f:
            f.write(mpd)
            mpd_path = Path(f.name)
            logger.debug("Saved playback MPD file to %s", mpd_path)

        mpd_etree = ElementTree.fromstring(mpd)
        mpd_start_time_string = mpd_etree.attrib["availabilityStartTime"]
        mpd_start_time = datetime.fromisoformat(mpd_start_time_string)
        logger.debug("MPD@availabilityStartTime=%s", mpd_start_time_string)

        return mpd_path, mpd_start_time

    def handle_rewind(self, target_date: datetime) -> None:
        some_base_url = next(iter(self._streams)).base_url

        target = target_date.timestamp()
        if reference := self.rewind_tree.closest(target):
            reference_sequence = reference.value
        else:
            reference_sequence = None

        print("***", reference_sequence)

        sl = SegmentLocator(
            some_base_url,
            reference_sequence=reference_sequence,
            temp_directory=self._playback.get_temp_directory(),
            session=self._playback.session,
        )
        sequence, falls_into_gap = sl.find_sequence_by_time(target)
        rewound_segment = self._playback.get_downloaded_segment(sequence, some_base_url)
        target_date_diff = target_date - rewound_segment.ingestion_start_date

        self.rewind_tree.insert(rewound_segment.metadata.ingestion_walltime, sequence)

        self._mpd_path, self._mpd_start_time = self._compose_mpd(
            rewound_segment.metadata
        )

        self._mpv.command("loadfile", str(self._mpd_path))
        self._mpv.command("set_property", "pause", "yes")
        self._mpv.command(
            "script-message",
            "yp:rewind-completed",
            str(self._mpd_path),
            str(target_date_diff.total_seconds()),
        )

    def start(self) -> None:
        some_base_url = next(iter(self._streams)).base_url

        latest_sequence = request_reference_sequence(
            some_base_url, self._playback.session
        )
        latest_segment = self._playback.get_downloaded_segment(
            latest_sequence, some_base_url
        )
        self.rewind_tree.insert(
            latest_segment.metadata.ingestion_walltime, latest_sequence
        )

        self._mpd_path, self._mpd_start_time = self._compose_mpd(
            latest_segment.metadata
        )
        self._mpv.command("loadfile", str(self._mpd_path))


@cloup.command("listen", help="Start listening to mpv messages.")
@cloup.option_group(
    "Input options",
    cloup.option(
        "--ipc-server",
        metavar="FILE",
        type=click.Path(path_type=Path),
        required=True,
        help="Path to mpv Unix socket.",
    ),
    cloup.option(
        "-af",
        "--audio-format",
        metavar="SPEC",
        type=FormatSpecParamType(FormatSpecType.AUDIO),
        help="Audio format to play.",
        default="itag eq 140",
    ),
    cloup.option(
        "-vf",
        "--video-format",
        metavar="SPEC",
        type=FormatSpecParamType(FormatSpecType.VIDEO),
        help="Video format to play.",
        default="best([@webm or @mp4] and @<=720p and @30fps)",
    ),
)
@yt_dlp_option
@cache_options
@stream_argument
@constraint(require_any, ["audio_format", "video_format"])
@click.pass_context
def listen(
    ctx: click.Context,
    ipc_server: Path,
    audio_format: str,
    video_format: str,
    yt_dlp: bool,
    force_update_cache: bool,
    no_cache: bool,
    stream_url: str,
) -> int:
    playback = create_playback(ctx)

    @atexit.register
    def on_exit():
        shutil.rmtree(playback.get_temp_directory())

    if audio_format:
        logger.debug("Query audio streams by format spec", spec=audio_format)
        queried_audio_streams = query_streams_or_exit(
            playback.streams, audio_format, "--audio-format", allow_many=False
        )

    if video_format:
        logger.debug("Query video stream by format spec", spec=video_format)
        queried_video_streams = query_streams_or_exit(
            playback.streams, video_format, "--video-format", allow_many=False
        )

    all_queried_streams = Streams(queried_audio_streams + queried_video_streams)

    listener = Listener(ipc_server, playback, all_queried_streams)
    listener.start()


cli = deepcopy(base_cli)

cli.add_command(listen)

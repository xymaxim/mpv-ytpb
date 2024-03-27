from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Self, TypeGuard
from xml.etree import ElementTree

import structlog
from python_mpv_jsonipc import MPV

from ytpb.actions.compose import compose_dynamic_mpd
from ytpb.locate import SegmentLocator
from ytpb.playback import Playback
from ytpb.segment import SegmentMetadata
from ytpb.types import SegmentSequence, SetOfStreams, Timestamp
from ytpb.utils.remote import request_reference_sequence

logger = structlog.get_logger(__name__)

YTPB_CLIENT_NAME = "yp"


@dataclass
class RewindTreeNode:
    key: Timestamp
    value: SegmentSequence
    left: Self | None = None
    right: Self | None = None


@dataclass
class RewindTreeMap:
    """A binary search tree implementation to store key-value pairs.

    Keys represent timestamps of segments, while values are sequence numbers.
    """

    root: RewindTreeNode | None = None

    @staticmethod
    def _is_tree_node(node: RewindTreeNode | None) -> TypeGuard[RewindTreeNode]:
        return node is not None

    @staticmethod
    def _insert(
        node: RewindTreeNode | None, key: Timestamp, value: SegmentSequence
    ) -> RewindTreeNode:
        if not RewindTreeMap._is_tree_node(node):
            return RewindTreeNode(key, value, None, None)
        else:
            if key < node.key:
                left = RewindTreeMap._insert(node.left, key, value)
                return RewindTreeNode(node.key, node.value, left, node.right)
            elif key > node.key:
                right = RewindTreeMap._insert(node.right, key, value)
                return RewindTreeNode(node.key, node.value, node.left, right)
            else:
                return RewindTreeNode(node.key, value, node.left, node.right)

    def insert(self, key: Timestamp, value: SegmentSequence) -> None:
        """Insert a pair of timestamp and sequence number into the tree."""
        self.root = RewindTreeMap._insert(self.root, key, value)

    @staticmethod
    def _closest(
        node: RewindTreeNode | None, target: Timestamp, closest: RewindTreeNode
    ) -> RewindTreeNode | None:
        if not RewindTreeMap._is_tree_node(node):
            return closest
        else:
            result = closest
            if abs(target - closest.key) > abs(target - node.key):
                result = node
            if target < node.key:
                return RewindTreeMap._closest(node.left, target, result)
            elif target > node.key:
                return RewindTreeMap._closest(node.right, target, result)
            else:
                return result

    def closest(self, target: Timestamp) -> RewindTreeNode | None:
        """Find the node closest to the target timestamp."""
        if self.root is None:
            return None
        return RewindTreeMap._closest(self.root, target, self.root)


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

        self.rewind_tree = RewindTreeMap()

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

        sl = SegmentLocator(
            some_base_url,
            reference_sequence=reference_sequence,
            temp_directory=self._playback.get_temp_directory(),
            session=self._playback.session,
        )
        locate_result = sl.find_sequence_by_time(target)
        rewound_segment = self._playback.get_downloaded_segment(
            locate_result.sequence, some_base_url
        )

        self.rewind_tree.insert(
            rewound_segment.metadata.ingestion_walltime, locate_result.sequence
        )

        self._mpd_path, self._mpd_start_time = self._compose_mpd(
            rewound_segment.metadata
        )

        self._mpv.command("loadfile", str(self._mpd_path))
        self._mpv.command("set_property", "pause", "yes")
        self._mpv.command(
            "script-message",
            "yp:rewind-completed",
            str(self._mpd_path),
            str(locate_result.time_difference),
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

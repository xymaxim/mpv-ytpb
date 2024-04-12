from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree

import structlog
from python_mpv_jsonipc import MPV

from ytpb.actions.compose import compose_dynamic_mpd
from ytpb.playback import Playback
from ytpb.segment import SegmentMetadata
from ytpb.types import SetOfStreams
from ytpb.utils.remote import request_reference_sequence

logger = structlog.get_logger(__name__)

YTPB_CLIENT_NAME = "yp"


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
            mode="w",
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
        moment = self._playback.locate_moment(target_date)
        rewound_segment = self._playback.get_segment(
            moment.sequence, next(iter(self._streams))
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
            str(moment.cut_at),
        )

    def start(self) -> None:
        some_stream = next(iter(self._streams))

        latest_sequence = request_reference_sequence(
            some_stream.base_url, self._playback.session
        )
        latest_segment = self._playback.get_segment(latest_sequence, some_stream)
        self._playback.rewind_history.insert(
            latest_segment.metadata.ingestion_walltime, latest_sequence
        )

        self._mpd_path, self._mpd_start_time = self._compose_mpd(
            latest_segment.metadata
        )
        self._mpv.command("loadfile", str(self._mpd_path))

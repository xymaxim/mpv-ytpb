import atexit
import shutil
from copy import deepcopy
from pathlib import Path

import click
import cloup
import structlog
from cloup.constraints import constraint, require_any

from ytpb.cli import base_cli
from ytpb.cli.common import create_playback, query_streams_or_exit, stream_argument
from ytpb.cli.options import cache_options, yt_dlp_option
from ytpb.cli.parameters import FormatSpecParamType, FormatSpecType
from ytpb.streams import Streams

from ytpb_mpv.listener import Listener

logger = structlog.get_logger(__name__)


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
cli.help = "A socket listener for mpv messages"
cli.add_command(listen)

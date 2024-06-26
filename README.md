# mpv-ytpb

*mpv-ytpb* is an mpv hook to play and rewind YouTube live streams
interactively. The script detects `ytpb://<STREAM>` links passed to the mpv
player, and launches the
[ytpb-mpv](https://github.com/xymaxim/mpv-ytpb/tree/main/python) socket listener
to handle the rewind functionality. A set of script key bindings allows to play,
mark, and export (TODO) past moments of live streams.

![mpv-ytpb user interface](./images/mpv-ytpb-window.gif)

*A screenshot of the script user interface. https://www.youtube.com/live/aofZxPM0l58.*

## Install

*mpv-ytpb* requires [ytpb](https://github.com/xymaxim/ytpb) to be
installed in your `PATH`. Also, playing needs a custom mpv build with patched
FFmpeg (see xymaxim/ytpb#4 for details).

1. Build a custom mpv: follow
   [this](https://github.com/xymaxim/ytpb/issues/4#issuecomment-1975844281)
   compile instruction or
   [use](https://github.com/xymaxim/ytpb/issues/4#issuecomment-2012443084) this
   container image
2. Install [ytpb](https://github.com/xymaxim/ytpb): ``$ pipx install ytpb``
3. Install [ytpb-mpv](https://github.com/xymaxim/mpv-ytpb/tree/main/python): ``$
   pipx inject ytpb ytpb-mpv --include-apps``
4. Copy `ytpb.lua` to your mpv `~~/scripts`
   [directory](https://mpv.io/manual/master/#files)

To update to the newer version of the script, do:

1. Replace `ytpb.lua` with the new one
2. Upgrade the installed packages: `$ pipx upgrade --include-injected ytpb`

## Usage

    $ mpv ytpb://<STREAM>,

where `<STREAM>` is the YouTube video URL or ID of a live stream.

It will open a player with a stream playing and bind `Ctrl+p` key to activate
the script [main menu](#key-bindings).

### Rewinding

Rewinding to a moment in a stream is bound to `r` key. It opens the date and
time picker with dynamically bound keys: select (`LEFT`, `RIGHT`) and change
(`UP`, `DOWN`) input parts, close (`ESC`).

### Seeking

#### Nearby seeking

If ``cache=yes`` is set in ``mpv.conf`` (recommended), seeking works smoothly
within cached ranges as well as the mpv's A-B loop functionality with the
default keys.

#### Seeking by rewinding

Seeking backward and forward outside of cached ranges is possible with `<` and
`>` keys. The seeking by rewinding is a quick form of rewinding, with no need to
enter a target date. A user-defined, arbitrary offset is used instead. The
offset value can be changed with `F` key.

The format of the input offset value (after `F` pressed) is
`[<days>d][<hours>h][<minutes>m][<seconds>s]`, where each part is optional, but
order must be preserved. For example: `1h`, `1h30m`, `120m`.

### Taking screenshots

Taking screenshots is bound to `s` key. The captured screenshot is saved in the
current directory to a file named `<STREAM-ID>-<DATE>-<TIME>.jpg`, where times
are in UTC.

### Mark mode

Mark mode can be enabled by marking a point with `m` key. Points are labeled A
and B. Marking works in a cycle manner. The current point can be edited by
changing a position (after seeking or rewinding) with `e` key. After points
selected, you can jump back to them with `a` and `b` keys.

## Key bindings

By default, there is only one key available—it toggles the script main menu:

`Ctrl-p` — activate and deactivate the main menu

After activation, the following key bindings are dynamically added:

### Rewind and seek

* `r` — rewind to a date
* `<`/`>` — seek back and forward to a relative offset
* `F` — change a seek offset

### Mark mode

* `m` — mark a new point labeled A or B
* `e` — edit current point
* `a`/`b` — go to point A or B

### Other

* `s` — take a screenshot and save to a file
* `C` — toggle clock
* `T` — change global timezone
* `q` — quit

## How it works

### Rewinding and seeking

Rewinding and seeking actions are associated with sending the `yp:rewind` script
message to *ytpb-mpv* and listening back to a `yp:rewind-completed` message to
run a complete callback. At the same time, *ytpb-mpv* composes a new MPEG-DASH
MPD starting with a target media segment and executes the `loadfile`
command. The paused first segment is appeared on a screen, and the script seeks
to a start position. It would be nice to avoid
that short quirk and seek straight to the start position in the future.

## Known limitations

### Stream clock and gaps

The clock showing the date and time is not guaranteed to display the actual
time. Going into details, we rely on the `Ingestion-Walltime-Us` metadata values
of the MPEG-DASH media segments. While the streaming latency can be specified
(TODO), there is another issue, more significant. In fact, the clock shows a
current playing offset relative to the MPEG-DASH MPD start time (the
`Ingestion-Walltime-Us` value of the first media segment). If playing encounters
a gap, the playing timeline does not update according to new perturbed
timestamps after a gap. A workaround solution would be to add a key to sync a
clock (create and load a new manifest at the current time and continue playing).

## Acknowledgements

The script is written in [Fennel](https://fennel-lang.org/), a Lisp-like
language that compiles to Lua.

The hook uses the
[python-mpv-jsonipc](https://github.com/iwalton3/python-mpv-jsonipc) package to
communicate with mpv via JSON-IPC.

The date and time picker was inspired by the
[seek-to.lua](https://github.com/occivink/mpv-scripts/tree/master?tab=readme-ov-file#seek-tolua)
script.

## License

The project is licensed under the MIT license. See [LICENSE](LICENSE) for details.

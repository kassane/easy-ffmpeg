# Architecture — easy-ffmpeg (Carbon)

```
                              ┌─────────────────┐
                              │  src/main.carbon│  Run() — dispatch only
                              └────────┬────────┘
                                       │ argv[1] == Constants.Cmd*
                     ┌─────────────────┼─────────────────┐
                     ▼                 ▼                 ▼
              CliConvert        CliCompress        CliTrim        ... (18 files in src/cli/*.carbon)
                     │                 │                 │
                     └─────────────────┼─────────────────┘
                                       ▼
                              ┌─────────────────┐
                              │  ArgsBuilder    │  src/core/ArgsBuilder.carbon
                              │  Builder        │  Add("-i", input) — single site
                              │  ToSystemCmd()  │  for every flag
                              └────────┬────────┘
                                       │ String cmd
                              ┌────────┴────────┐
                              │   Validate      │  exists, time, codec allowed
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Process.Exec  │  fork()+execvp() via C++ interop
                              └────────┬────────┘
                                       │ fork/exec
                              ┌────────┴────────┐
                              │  ffmpeg/ffprobe │  external, not linked
                              └─────────────────┘
```

## Why This Shape

* **One builder, one exec** — eliminates duplication (rule: avoid redundancies). Every `"-c:v"`, `"-b:a"`, `"copy"` flows through `Constants.carbon` → `ArgsBuilder` method. No `cli/*.carbon` touches raw literals.
* **Exec via C++ interop, not libav*** — Carbon 0.1 nightly has no safe `libav*` import (`avcodec.h` pulls `<atomic>`, templates). `fork()+execvp()` is proven (`import Cpp library "<cstdio>"` works per `toolchain/docs`). Keeps build to one `carbon build` line, no `pkg-config` at compile time.
* **Dry-run first** — `ArgsBuilder.ToSystemCmd()` testable without ffmpeg installed.

## File Responsibilities

| File | Owns | Must NOT contain |
|------|------|------------------|
| `Constants.carbon` | every magic string/number: flags, codecs, presets, exit codes, defaults | logic |
| `ArgsBuilder.carbon` | module-level functions (`Clear`, `AddFlagValue`, `AddMany`, `StartFfmpeg`, `ToSystemCmd`) backed by C++ static buffer | exec or validation |
| `Process.carbon` | `fn Exec(String) -> i32` single call to `process::run_str` (fork+execvp) | builder logic |
| `Validate.carbon` | `Exists`, `ParseTime`, `IsAllowedCodec` | builder logic |
| `cli/Convert.carbon` etc | parse own flags via `Cpp.cli`, call `ArgsBuilder.AddFlagValue(Constants.X(), Y)` | raw `"-c:v"` literals |
| `main.carbon` | dispatch `if (arg == Constants.CmdConvert)` | builder/exec duplication |

## Smart Remux (ported from Crystal reference)

`convert` auto-copies streams when both video and audio are compatible with the target container:

1. Probes input codecs via `ffprobe` (`probe_stream_codec()`)
2. Infers output format from extension (`format_for_ext()`)
3. Checks container compatibility tables (`video_compatible()`, `audio_compatible()`)
4. If both compatible → `-c copy` (instant, zero quality loss)
5. If only one compatible → copies that stream, re-encodes the other
6. If neither compatible → re-encodes everything with ffmpeg defaults

### Container Compatibility

| Container | Video | Audio |
|-----------|-------|-------|
| mp4 | h264, hevc, mpeg4, av1 | aac, mp3, ac3, opus, flac |
| matroska | h264, hevc, vp8, vp9, av1, theora, prores, ffv1 | aac, mp3, ac3, dts, flac, opus, vorbis |
| webm | vp8, vp9, av1 | opus, vorbis |
| mov | h264, hevc, prores, mpeg4, mjpeg | aac, mp3, ac3, alac, flac |
| mpegts | h264, hevc, mpeg2video | aac, mp3, ac3 |

Implementation: `std::unordered_map<format, std::unordered_set<codec>>` — O(1) lookup, data-driven (no if-chains).

## Per-Format Presets

`compress --web/--mobile/--streaming` adapts codec to output format via C++ `build_compress_args()` — single function call returns all codec/crf/preset/audio args for a given preset+format combo:
- `.webm` → `libvpx-vp9` (VP9)
- `.mp4`/`.mkv` → `libx264` (H.264) or `libx265` (H.265)

`--no-subs` strips subtitle tracks (auto-applied for `--web`/`--mobile`).

## Video Normalization

For h264/h265 output, auto-adds:
- `format=yuv420p` if source pixel format is not yuv420p/yuv420p10le
- `scale=trunc(iw/2)*2:trunc(ih/2)*2` if source dimensions are odd

## Data Flow Example

`easy-ffmpeg trim in.mp4 --start 10 --duration 5 out.mp4`

1. `main` → `CliTrim.Run(argv)` parses `--start`/`--duration` via `Constants.FlagStart`.
2. `Validate.ParseTime("10") -> 10_000ms`, `Validate.Exists("in.mp4")`.
3. `ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), "in.mp4");
  ArgsBuilder.AddFlagValue(Constants.FlagSeek(), "10");
  ArgsBuilder.AddFlagValue(Constants.FlagDuration(), "5");
  ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecCopy());`
4. `if (dryRun) { /* print argv via a future ToString() */ } else { let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd(); return Process.Exec(cmd); }`
5. Underlying: `ffmpeg -ss 10 -t 5 -i in.mp4 -c copy out.mp4` — verified against `ffmpeg -h full` (seek is input option, `-t` duration, `-c copy` stream copy).

## Constraints from Toolchain

* No `Vector`, no `String.format` in prelude — use `Array(String, MaxArgs)` (64) + `len: i32`. Marked `// ponytail: fixed 64, heap Vector when prelude ships`.
* No arg-parser library — hand-roll `while (i < argc) { if (arg == Constants.FlagX) ... }` in each `cli/*.carbon` but **share** the `Constants.FlagX` table.
* `carbon build` takes `FILE... -- [<CLANG-ARG>... -- <EXTRA_CLANG_LINK_ARGS>...]` — extra link args go after `--`. For now no extra libs needed (only `system`).


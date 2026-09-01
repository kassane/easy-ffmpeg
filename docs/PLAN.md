# Plan — easy-ffmpeg on Carbon (6 Phases)

> Source: deep research 2026.09.01, `ffmpeg -h` (17 828 lines), `carbon --help` / `carbon build --help`, Carbon roadmap 0.1 nightly.

## Reality Check (why wrapper, not libav* SDK)

* **Carbon 0.1 nightly** (`0.0.0-0.nightly.2026.09.01+f519ccc`) can `import Cpp library "<cstdio>"` and call `Cpp.putchar`. `process::run_str()` works via a `std::string` bridge (fork+execvp, no shell). Custom headers (`import Cpp library "ffi_helper.hpp"`) compile/link when the include dir is passed via `carbon build ... -- -std=c++23 -I<dir>`. It **cannot** yet reliably import full `libavcodec/avcodec.h` template-heavy headers, nor does it expose `String` formatting or heap `Vector<String>`. Checked via `lib/carbon/core` (only `io.carbon`, `prelude/*`).
* **CRASH BUG**: cross-package references to package-level `let` constants trigger a CHECK failure in lowering (`const_id.is_concrete()`). Workaround: use FUNCTIONS instead of `let` constants in `Constants.carbon`. See `docs/CARBON_TOOLCHAIN.md` for details.
* FFmpeg project itself recommends CLI for 90% use-cases; `libav*` (`avcodec_send_packet`/`avcodec_receive_frame`) is for custom players/transcoders. Wrapper satisfies “easier CLI” with 1/10th the Carbon complexity.
* Therefore **Phase 1–3 = Argv-builder + exec**, Phase 5 (optional) = migrate to `libav*` interop when Carbon 0.2 ships.

---

## Phase 0 — Scaffolding (Day 0, 2h)

- [x] `CARBON=$PWD/carbon_toolchain-0.0.0-0.nightly.2026.09.01/bin/carbon` in `scripts/env.sh`
- [x] `src/main.carbon` minimal `fn Run() { Core.Print(0); }` builds with `carbon build --output=easy-ffmpeg`
- [x] `carbon format` passes, `scripts/loop-build.sh` watches `src/**/*.carbon`

Exit: `carbon build` green on clean tree.

## Phase 1 — Core (Constants + ArgsBuilder + Process) (Day 1)

Single responsibility, zero duplication:

```
src/core/Constants.carbon  — choice VideoCodec { H264, H265, Av1, Vp9, Copy }
                             choice AudioCodec { Aac, Mp3, Opus, Copy }
                             fn FlagVideoCodec() -> String { return "-c:v"; }  // FUNCTIONS, not `let` (crash bug)
                             fn DefaultVideoBitrateKbps() -> i32 { return 2500; } // etc — ONLY place for literals
src/core/ArgsBuilder.carbon — accumulates argv tokens via C++ global static std::string
                              (Carbon can't hold mutable state). Cpp.argv_add_token / argv_build_cmd
src/core/Process.carbon    — fn Exec(cmd: Cpp.std.string) -> i32
                              { import Cpp library "ffi_helper.hpp"; return Cpp.process.run_str(cmd); }
src/core/Validate.carbon   — fn Exists(path: String) -> bool, fn ParseTime(s: String) -> i64
```

Rules:
- No string literal `"h264"` outside `Constants.carbon` — `grep -R "\"h264\""` must hit only that file.
- No duplicate `"-b:v"` handling — `ArgsBuilder.AddVideoBitrate()` is the single site.

- [x] `Constants.carbon`: `choice VideoCodec/AudioCodec`, `fn Flag*`, `fn Exit*`, `fn MaxArgs` (functions, not `let` — see crash bug)
- [x] `ArgsBuilder.carbon`: C++ global static std::string accumulator via `ffi_helper.hpp`
- [x] `Process.carbon`: single `fn Exec(Cpp.std.string) -> i32` via `Cpp.process.run_str`
- [x] `Validate.carbon`: `Exists`, `ParseTime` (returns i64 ms), `IsAllowedCodec`
- [x] Unit self-check compiles with `carbon build`

Exit: unit demo compiles, `Builder` test via `carbon build` self-check.

## Phase 2 — CLI Dispatch (Day 2)

One file per subcommand, all delegate to `ArgsBuilder`:

| Subcommand | FFmpeg mapping (see `docs/FFMPEG_COVERAGE.md`) | Example |
|---|---|---|
| `convert` | `-i IN -c:v CODEC -c:a CODEC OUT` | `easy-ffmpeg convert in.mkv --to mp4 out.mp4` |
| `compress` | `-i IN -c:v libx264 -crf 23 -preset fast -b:a - [x] `grep -rn '2500|128k|"h264"' src --exclude=Constants.carbon` == 0 (help strings excluded) OUT` | `compress in.mp4 --crf 23` |
| `trim` | `-ss START -to END -i IN -c copy OUT` | `trim in.mp4 --start 10 --duration 30s out.mp4` |
| `resize` | `-i IN -vf scale=W:H OUT` | `resize in.mp4 --width 1280 --height 720` |
| `audio-extract` | `-i IN -vn -c:a CODEC -b:a BR OUT` | `audio-extract in.mp4 --format mp3 out.mp3` |
| `probe` | `ffprobe -v quiet -print_format json -show_streams` | `probe in.mp4 --json` |

`src/main.carbon` dispatch:

```
fn Run() {
  let argv = CollectArgv(); // via Cpp.import "<unistd.h>" or fixed test harness
  match (argv[1]) {
    case "convert" => return CliConvert.Run(argv);
    case "compress" => return CliCompress.Run(argv);
    ...
    case "--help" => return Help.Print();
  }
}
```

Carbon 0.1 has no `match` sugar yet — implement as `if (argv[1] == Constants.CmdConvert)`.

- [x] `src/main.carbon`: dispatch `if (arg == Constants.CmdConvert)` over 6 commands
- [x] `src/cli/Convert.carbon`, `Compress.carbon`, `Trim.carbon`, `Resize.carbon`, `AudioExtract.carbon`, `Probe.carbon`
- [x] `--help` for each subcommand
- [x] Every command calls `ArgsBuilder` only (no raw literals)

Exit: `./easy-ffmpeg --help` lists 6 commands, each `--help` prints forwarded `ffmpeg -h` excerpt.

## Phase 3 — Hardening (Day 3)

- Validate inputs **once** in `Validate.carbon` (file exists, time parse, codec allowed). No per-command duplicate checks.
- Dry-run flag: `ArgsBuilder.ToSystemCmd()` prints the command string without `Process.Exec` — testable without ffmpeg.
- Error codes in `Constants.carbon`: `fn ExitOk() -> i32 { return 0; }`, `fn ExitUsage() -> i32 { return 2; }`, `fn ExitFfmpegFailed() -> i32 { return 3; }`
- `scripts/probe-ffmpeg.sh` captures `ffmpeg -encoders`, `-decoders`, `-filters` into `docs/FFMPEG_COVERAGE.md` so choices stay in sync.

^- [x] `--dry-run` flag: `Builder.ToString()` without `Process.Exec`
^- [x] C++ build checks (`Cpp.build.check_no_magic/check_no_duplication`) replace .sh scripts
- [x] Exit codes `ExitOk/ExitUsage/ExitFfmpegFailed` used consistently
- [x] `scripts/probe-ffmpeg.sh` regenerates `docs/FFMPEG_COVERAGE.md`
- [x] `tests/smoke.sh` runs against `fixtures/in.mp4`

Exit: `scripts/loop-build.sh` runs `carbon build` + `sh tests/smoke.sh` (probes fixtures).

## Phase 4 — DX & Docs (Day 4)

- `README.md` quickstart, `docs/ARCHITECTURE.md` diagram, `docs/CARBON_TOOLCHAIN.md` (from `carbon --help`), `docs/RULES.md`.
- Shell completions generated from `Constants.Cmd*` (single source).

- [x] `docs/ARCHITECTURE.md`, `docs/CARBON_TOOLCHAIN.md`, `docs/RULES.md`
- [x] Shell completions generated from `Constants.Cmd*`
- [x] `./build --ci` wraps format + no-magic + build + smoke

Exit: fresh clone builds and passes smoke tests.

## Phase 5 — Feature Expansion (Day 5)

10 new subcommands + quality improvements to existing commands:

| Subcommand | FFmpeg mapping | Example |
|---|---|---|
| `concat` | `-f concat -safe 0 -i LIST -c copy` | `concat a.mp4 b.mp4 out.mp4 --copy` |
| `gif` | `-vf fps=N,scale=W:-1:flags=lanczos` | `gif in.mp4 out.gif --fps 15 --width 480` |
| `thumbnail` | `-ss TIME -vframes 1` or `-vf fps=1/N` | `thumbnail in.mp4 thumb.jpg --time 00:01:30` |
| `speed` | `-filter_complex [0:v]setpts=N*PTS;[0:a]atempo=N` | `speed in.mp4 out.mp4 --factor 2.0` |
| `rotate` | `-vf transpose=N` or `hflip`/`vflip` | `rotate in.mp4 out.mp4 --angle 90` |
| `watermark` | `-filter_complex overlay` or `-vf drawtext` | `watermark in.mp4 out.mp4 --image logo.png` |
| `subtitle` | `-vf subtitles=FILE` | `subtitle in.mp4 out.mp4 --file subs.srt` |
| `metadata` | `-map_metadata -1` or `-metadata key=val` | `metadata in.mp4 out.mp4 --strip` |
| `normalize` | `-af loudnorm=I=-16:TP=-1.5:LRA=11` | `normalize in.mp4 loud.mp4` |
| `replace-audio` | `-i AUDIO -map 0:v -map 1:a -c:v copy` | `replace-audio in.mp4 out.mp4 --audio music.mp3` |

Quality improvements to existing commands:
- `compress`: `--audio-codec`, `--video-bitrate` flags
- `resize`: `--scale tiktok`, `--scale instagram`, `--scale youtube` social presets
- `trim`: `--sseof` flag (seek from end)

- [x] 10 new CLI files created
- [x] Security audit passed (3 criticals fixed: temp file race, filter injection, numeric validation)
- [x] All 77 tests passing

Exit: `./easy-ffmpeg --help` lists 17 commands, all dry-run tests pass.

## Phase 6 — Optional libav* Migration (post-0.2)

Only after Carbon can `import Cpp library "libavcodec/avcodec.h"` without template errors:
- `src/interop/AvCodec.carbon` wraps `AVCodec*`, `AVFrame*` with RAII.
- Swap `Process.Exec("ffmpeg ...")` for direct `avformat_open_input` calls behind same CLI.

Not in MVP.

---

## Anti-Redundancy Checklist (review gate)

- [x] `grep -rn '"-c:v"' src --exclude=Constants.carbon` == 0
- [x] `grep -rn '2500|128k|"h264"' src --exclude=Constants.carbon` == 0 (help strings excluded)\|128k\|"h264"' src --exclude=Constants.carbon` == 0
- [x] One `ArgsBuilder` module, one `Process.Exec`, one `Validate` module.
- [x] New flag? Add to `Constants.carbon` + `ArgsBuilder` method, not copy-paste in `cli/*.carbon`.

## Looping Toolcall

```
while true; do
  carbon build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=/tmp/easy-ffmpeg \
    && /tmp/easy-ffmpeg --help \
    && /tmp/easy-ffmpeg convert --dry-run fixtures/in.mp4 --to mp4 /tmp/out.mp4 \
    && echo "green $(date)";
  inotifywait -e modify,create src/**/*.carbon docs/*.md;
done
# implemented as scripts/loop-build.sh
```

## Auto-Update Todolist

1. parses `docs/PLAN.md` checkboxes,
2. counts `src/**/*.carbon` vs plan phases,

## Risks

| Risk | Mitigation |
|---|---|
| Carbon `import Cpp` breaks on `<string>` heavy headers | Keep interop to `<cstdlib>`/`<cstdio>` only; smoke test every nightly bump |
| No `Vector<String>` in prelude | Use fixed `Array(String, 64)` + length var; document ceiling with `// ponytail: fixed 64, grow if needed` |
| ffmpeg flags drift | `scripts/probe-ffmpeg.sh` regenerates coverage md weekly |

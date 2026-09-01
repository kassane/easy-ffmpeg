# Architecture — easy-ffmpeg (Carbon)

```
                              ┌─────────────────┐
                              │  src/main.carbon│  Run() — dispatch only
                              └────────┬────────┘
                                       │ argv[1] == Constants.Cmd*
                     ┌─────────────────┼─────────────────┐
                     ▼                 ▼                 ▼
              CliConvert        CliCompress        CliTrim        ... (17 files in src/cli/*.carbon)
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


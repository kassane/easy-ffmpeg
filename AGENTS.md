# AGENTS.md — easy-ffmpeg

Friendly `ffmpeg`/`ffprobe` wrapper written in **Carbon** (vendored nightly toolchain). This file is the fast-ramp for agents; full context lives in `docs/`.

## Build & run (correct order matters)

```sh
. ./scripts/env.sh            # sets CARBON, FFMPEG_BIN, FFPROBE_BIN from repo root
"$CARBON" build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=easy-ffmpeg
./easy-ffmpeg --help
"$CARBON" format src/**/*.carbon
```

- Toolchain binary: `carbon_toolchain-0.0.0-0.nightly.2026.08.29/bin/carbon`. Resolve via `scripts/env.sh`, never hardcode in source.
- `build` extra args go after `--`: `"$CARBON" build f.carbon -- -I... -lavcodec`. Bare `-o` errors; always use `--output=NAME`.
- On-demand link needs `libgcc-11-dev` (per official docs).

## Hard-won facts (you WILL get these wrong first time)

- **Entry function is `fn Run()`, NOT `fn Main() -> i32`.** Using `Main` fails to link with `undefined symbol: main` (runtime expects `_CMain.Run`). Verified live.
- **`Cpp.char*` does not parse** (`char` is reserved). Use `Cpp.putchar(c as i32)` with `let c: Core.Char = 'H';`. `'\n'.Code()` doesn't exist — use `10 as i32`.
- **Working interop demo** (builds+runs, verified):
  ```carbon
  import Core library "io";
  import Cpp library "<cstdio>";
  fn Run() { let c: Core.Char = 'H'; Cpp.putchar(c as i32); Cpp.putchar(10 as i32); Core.Print(42); }
  ```
- Prelude has **no `Vector`, `String.format`, or heap allocator**. Use `Array(String, MaxArgs)` + `len` (ponytail comment marks the ceiling). No `match` — dispatch with `if`.
- **`let` does NOT infer types.** `let x = 42;` fails with `name 'x' not found` — you **must** annotate: `let x: i32 = 42;`. Every `let` needs an explicit type on 2026.08.29 nightly.
- Exec goes through `Cpp.system` in `src/core/Process.carbon` — the ONLY place. No `libav*` import yet (0.1 nightly can't safely import `avcodec.h` templates).
- **Every magic string/number lives in `src/core/Constants.carbon`** — `scripts/check-no-magic.sh` fails builds otherwise. Grep before adding.

## Workflow rules (from docs/RULES.md)

- **No duplication**: one builder, one exec, one validator. All `"-c:v"`/`"h264"`/**codecs** flow through `Constants.carbon` → `ArgsBuilder` methods.
- **Looping toolcall**: `scripts/loop-build.sh` (watch mode) or `--once` for one green check. Manual-review gate per `loop-engineering`.
- **Auto-update todo**: `docs/TODO.md` is GENERATED from `docs/PLAN.md` by `scripts/update-todo.sh`. Never hand-edit its table. `--check` gate in CI.
- **Verification**: no completion claim without a fresh `scripts/loop-build.sh --once` in the same message (per `verification-planning`). `--dry-run` prints the exact `ffmpeg ...` argv without forking.

## Verification commands

```sh
./scripts/loop-build.sh --once     # the green gate: build + smoke
./scripts/probe-ffmpeg.sh          # regen docs/FFMPEG_COVERAGE.md from live ffmpeg
./scripts/make-fixtures.sh         # regenerate tests/fixtures/in.mp4
```

## Subcommand → ffmpeg mapping source of truth

See `docs/FFMPEG_COVERAGE.md` (generated) and `docs/ARCHITECTURE.md` (data flow). Six commands: `convert`, `compress`, `trim`, `resize`, `audio-extract`, `probe`.

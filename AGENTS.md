# AGENTS.md — easy-ffmpeg

Must check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

Friendly `ffmpeg`/`ffprobe` wrapper written in **Carbon** (vendored nightly toolchain). This file is the fast-ramp for agents; full context lives in `docs/`.

## Build & run (correct order matters)

```sh
. ./scripts/env.sh            # sets CARBON, FFMPEG_BIN, FFPROBE_BIN from repo root
"$CARBON" build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=easy-ffmpeg
./easy-ffmpeg --help
"$CARBON" format src/**/*.carbon
```

- Toolchain binary: `carbon_toolchain-0.0.0-0.nightly.2026.09.01/bin/carbon`. Resolve via `scripts/env.sh`, never hardcode in source.
- `build` extra args go after `--`: `"$CARBON" build f.carbon -- -I... -lavcodec`. Bare `-o` errors; always use `--output=NAME`.
- On-demand link needs `libgcc-11-dev` (per official docs).

## Hard-won facts (you WILL get these wrong first time)

Must check [docs/CARBON_TOOLCHAIN.md](docs/CARBON_TOOLCHAIN.md) for full details.

- **Entry function is `fn Run()`, NOT `fn Main() -> i32`.** Using `Main` fails to link with `undefined symbol: main` (runtime expects `_CMain.Run`). Verified live.
- **`Cpp.char*` does not parse** (`char` is reserved). Use `Cpp.putchar(c as i32)` with `let c: Core.Char = 'H';`. `'\n'.Code()` doesn't exist — use `10 as i32`.
- **Working interop demo** (builds+runs, verified):
  ```carbon
  import Core library "io";
  import Cpp library "<cstdio>";
  fn Run() { let c: Core.Char = 'H'; Cpp.putchar(c as i32); Cpp.putchar(10 as i32); Core.Print(42); }
  ```
- Prelude has **no `Vector`, `String.format`, or heap allocator**. Use `Array(String, MaxArgs)` + `len` (ponytail comment marks the ceiling). No `match` — dispatch with `if`.
- **`let` does NOT infer types.** `let x = 42;` fails with `name 'x' not found` — you **must** annotate: `let x: i32 = 42;`. Every `let` needs an explicit type on 2026.09.01 nightly.
- Exec goes through `process::run_str()` (fork+execvp, no shell) in `src/core/ffi_helper.hpp` — the ONLY place. No `libav*` import yet (0.1 nightly can't safely import `avcodec.h` templates).
- **Inline C++**: `inline Cpp #'''...'''#` at file scope for small helpers. Use `ffi_helper.hpp` for shared code. See `docs/CARBON_TOOLCHAIN.md`.
- **Every magic string/number lives in `src/core/Constants.carbon`** — `scripts/check-no-magic.sh` fails builds otherwise. Grep before adding.

## Workflow rules (from docs/RULES.md)

Must check [docs/RULES.md](docs/RULES.md)

- **No duplication**: one builder, one exec, one validator. All `"-c:v"`/`"h264"`/**codecs** flow through `Constants.carbon` → `ArgsBuilder` methods.
- **Looping toolcall**: `scripts/loop-build.sh` (watch mode) or `--once` for one green check. Manual-review gate per `loop-engineering`.
- **Verification**: no completion claim without a fresh `scripts/loop-build.sh --once` in the same message (per `verification-planning`). `--dry-run` prints the exact `ffmpeg ...` argv without forking.

## Verification commands

```sh
./scripts/loop-build.sh --once     # the green gate: build + smoke
./scripts/probe-ffmpeg.sh          # regen docs/FFMPEG_COVERAGE.md from live ffmpeg
./scripts/make-fixtures.sh         # regenerate tests/fixtures/in.mp4
```

## Subcommand → ffmpeg mapping source of truth

See `docs/FFMPEG_COVERAGE.md` (generated) and `docs/ARCHITECTURE.md` (data flow). 18 commands: `convert`, `compress`, `trim`, `resize`, `audio-extract`, `probe`, `concat`, `gif`, `thumbnail`, `speed`, `rotate`, `watermark`, `subtitle`, `metadata`, `normalize`, `replace-audio`, `crop`, `colordetect`.

## Build command (mandatory)

**Always use `make` or `./build`**, never direct `carbon build`:
```sh
make                      # preferred: handles bootstrap + build chain
make once                 # build + one-shot verify
./build --output=easy-ffmpeg  # also valid: applies -std=c++23, -Isrc/core, link flags
carbon build src/main.carbon ...  # WRONG: misses C++23, -I, link flags → silent bugs
```

`build.carbon` centralizes compiler flags, include paths, and link flags. Direct `carbon build` bypasses all of that and produces binaries with wrong C++ standard, missing includes, or unresolved symbols.

**If `build.carbon` is modified, rebuild it first.** The `./build` binary is the compiled form of `build.carbon` — a stale binary silently ignores your changes. `Makefile` handles this automatically via dependency tracking. Manual rebuild:
```sh
. ./scripts/env.sh
"$CARBON" build build.carbon src/core/*.carbon --output=build -- -std=c++23 -Isrc/core
```

## Attribution

When AI agents contribute code, commit messages must include `Assisted-by: <agent-name>` in the trailer block. Example:
```
fix: handle empty codec string

Co-authored-by: human <user@example.com>
Assisted-by: <agent-name>
```

## Formatting (post-change)

After every code change, run `make fmt` before committing. This formats Carbon files with `carbon format` and C++ headers with `clang-format --style=google`. Keep markdown files (README, CHANGELOG, docs/*.md) in sync with actual test counts, versions, and features. A formatting-only commit is acceptable — never mix formatting with logic changes.

## Toolchain features tested (2026-09-01)

Must check [docs/CARBON_TOOLCHAIN.md](docs/CARBON_TOOLCHAIN.md) — full reference for what works and what doesn't.

**Quick reference:**
- Works: OOP, generics, interfaces, control flow, C++ FFI (C++23), Optional, inline C++
- Doesn't work: Range, match/switch/choice, interface dispatch, class inheritance, tuple destructuring, default params, operator overloading, ternary, pointer arithmetic, varargs, `<vector>` from Carbon, lambda/std::function

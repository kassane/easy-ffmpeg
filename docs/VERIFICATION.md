# Verification Plan — easy-ffmpeg

> Per `verification-planning/SKILL.md`. No completion claim without a **fresh** `scripts/loop-build.sh --once` run in this message. A green build does not prove a feature; check the observable new state (`--help` lists the command, `--dry-run` prints the exact `ffmpeg ...` args).

## Phase gates (evidence path)

| Phase | Claim | Evidence command (fresh) | Passing observable |
|-------|-------|--------------------------|--------------------|
| 0 | Toolchain builds a Carbon file | `scripts/env.sh && CARBON build src/main.carbon --output=/tmp/easy-ffmpeg` | exit 0, `/tmp/easy-ffmpeg` runs |
| 1 | `ArgsBuilder` assembles argv without magic literals | `scripts/loop-build.sh --once --check` | exit 0; `grep` no-magic passes |
| 1b | `Builder` unit check | `CARBON build tests/demo.carbon --output=/tmp/demo && /tmp/demo` | prints expected command string |
| 2 | Each subcommand maps to correct ffmpeg args | `easy-ffmpeg trim --dry-run in.mp4 --start 10 --duration 5 out.mp4` | prints `ffmpeg -ss 10 -t 5 -i in.mp4 -c copy out.mp4` (compare to `ffmpeg -h`) |
| 3 | Hardening: validate-once, dry-run, error codes | `scripts/loop-build.sh --once` | exit 0; invalid time → `ExitUsage` 2 |
| 4 | DX: completions + CI checks | `./build --ci` (C++ native, wraps all gates) | all exit 0 |
| 5 | Feature expansion: 16 commands | `bash tests/test_new_dry_run.sh && bash tests/test_dry_run.sh` | all 45+ dry-run pass |

## Trust boundaries (never skip)

- `Validate.Exists` on every input/output path before `Process.Exec`.
- `Validate.ParseTime` and `Validate.IsAllowedCodec` run once in `ArgsBuilder` caller, not per flag.
- `Process.Exec` uses fork()+execvp() — see `docs/SECURITY.md` (no shell injection).

## How a failure is diagnosed

Per `systematic-debugging/SKILL.md`, root-cause-first:
1. Reproduce: `CARBON build src/... --output=/tmp/easy-ffmpeg` capture full stderr.
2. Narrow: `CARBON compile --phase=check` to isolate check vs codegen.
3. Fault-inject: pass bad path/time/codec through `--dry-run` (no fork), assert error code.
4. Never patch symptoms per-caller; fix `ArgsBuilder`/`Validate` shared site (single source).

## Fixtures

- `fixtures/in.mp4` — tiny generated clip (create once via `ffmpeg -f lavfi -i testsrc=d=1:s=64x64 -f lavfi -i sine=f=440:d=1 -shortest`). Committed so smoke tests are hermetic; regenerate script in `scripts/make-fixtures.sh`.

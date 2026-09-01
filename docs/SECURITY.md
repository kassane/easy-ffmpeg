# Security — easy-ffmpeg

> Per `security-audit/SKILL.md`. The wrapper forks `ffmpeg` via `fork()+execvp()` (no shell). If `cmd` is built from untrusted user strings without validation, this is shell-command injection.

## Threat model

| Input | Validation |
|-------|-----------|
| Input path (`-i X`) | `Validate.Exists(X)`; reject `;`, `$( )`, backtick, `&&`, `|` before appending to argv |
| Output path | same as input path; reject control chars |
| Time (`--start 00:01:00`, `--duration 30s`) | Parsed via `Cpp.process.parse_time_ms` in Validate; numeric-only grammar |
| Codec (`--codec h264`) | `Validate.IsAllowedCodec` matches allow-list, never free-text |
| Preset / bitrate / crf | Presets defined in `Constants.carbon` (PresetWeb/Mobile/Streaming/Compress) |

Rule: **any user string that reaches `ToSystemCmd()` must pass a `Validate.*` allow-list/parser first.** Nothing reaches `process::run_str` unvalidated.

### New subcommand security (Phase 5)

- `concat`: temp file uses `mkstemp()` (no symlink race), cleaned up after exec
- `watermark`: drawtext text escaped via `escape_drawtext()` (resists `:`, `'`, `\` injection)
- `speed`: `--factor` validated as numeric before filter interpolation
- `rotate`: `--angle` whitelist: only `90`, `180`, `270` accepted
- `subtitle`: `--file` path validated via `ValidatePath()` before use
- `watermark --image`: validated via `ValidatePath()` before use
- All numeric inputs (`--fps`, `--width`, `--every`, `--factor`) range-checked > 0
- All commands return actual exit code from ffmpeg (not hardcoded 0)

## Injection-proofing

- Build argv as an `Array(String)` and **join with spaces only after validation**, never concatenate raw input.
- Prefer spaces between args; if a value legitimately contains a space (path), reject it or escape. MVP rejects.
- Add `--dry-run` to print `ToSystemCmd()` — a trivially auditable surface before any fork.

## Code review checklist (from skill)

- [ ] no `fork+exec` call site outside `src/core/ffi_helper.hpp` (process::run_str)
- [ ] `Validate.*` invoked before any `builder.Add(Constants.FlagInput, input)`
- [ ] `grep -n 'system(' src` → only in `ffi_helper.hpp` (build tool only, via `run_shell`)
- [ ] `grep -n 'run_str(' src` → only in `ffi_helper.hpp` and `Process.carbon`
- [ ] no secrets/env-dump in help output or `--debug`

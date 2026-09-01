# Security — easy-ffmpeg

> Per `security-audit/SKILL.md`. The wrapper forks `ffmpeg` via `fork()+execvp()` (no shell). If `cmd` is built from untrusted user strings without validation, this is shell-command injection.

## Threat model

| Input | Validation |
|-------|-----------|
| Input path (`-i X`) | `ValidatePath(X)` — rejects `..`, `'`, `\n`, `\r`, `\0`, non-regular files |
| Output path | User-controlled (expected for CLI tool). Only input paths validated via `ValidatePath()`.
| Time (`--start 00:01:00`, `--duration 30s`) | Parsed via `Cpp.process.parse_time_ms` in Validate; numeric-only grammar |
| Codec (`--codec h264`) | `Validate.IsAllowedCodec` matches allow-list, never free-text |
| Preset / bitrate / crf | Presets defined in `Constants.carbon` (PresetWeb/Mobile/Streaming/Compress) |
| Text watermark (`--text`) | `escape_drawtext()` escapes `: ' \ ; % [ ]` for ffmpeg drawtext filter |
| SRT path (`--file`) | `ValidatePath()` + `build_subtitle_filter()` escapes `\ ' : [ ]` |
| Concat file paths | `build_concat_list_2()` escapes `'` in filenames |
| Speed factor (`--factor`) | `validate_numeric()` blocks non-numeric input |
| Rotation angle (`--angle`) | Whitelist: only `90`, `180`, `270` accepted |

Rule: **any user string that reaches `ToSystemCmd()` must pass a `Validate.*` allow-list/parser first.** Nothing reaches `process::run_str` unvalidated.

### Injection-proofing (Phase 5 + hardening)

- `concat`: temp file uses `mkstemp()` (no symlink race), cleaned up after exec
- `watermark`: drawtext text escaped via `escape_drawtext()` (resists `: ' \ ; % [ ]` injection)
- `speed`: `--factor` validated as numeric before filter interpolation
- `rotate`: `--angle` whitelist: only `90`, `180`, `270` accepted
- `subtitle`: `--file` path validated via `ValidatePath()` + filter chars escaped
- `watermark --image`: validated via `ValidatePath()` before use
- All numeric inputs (`--fps`, `--width`, `--every`, `--factor`) range-checked > 0
- All commands return actual exit code from ffmpeg (not hardcoded 0)

## Injection-proofing

- Build argv as an `Array(String)` and **join with spaces only after validation**, never concatenate raw input.
- `validate_path()` rejects `'`, `\n`, `\r`, `\0` to block injection in concat lists and ffmpeg filters.
- `escape_drawtext()` escapes `: ' \ ; % [ ]` to block filter injection.
- `build_subtitle_filter()` escapes `\ ' : [ ]` in SRT paths.
- `build_concat_list_2()` escapes `'` in filenames (standard single-quote escaping).
- `argv_build_cmd()` escapes `"` inside double-quoted arguments.
- Add `--dry-run` to print `ToSystemCmd()` — a trivially auditable surface before any fork.

## Execution paths

| Function | Mechanism | Used by |
|----------|-----------|---------|
| `process::run_str()` | `fork()+execvp()` (POSIX), `_spawnvp()` (Windows) | `Process.Exec()` — all CLI commands |
| `run_progress()` | `fork()+execvp()` with pipe (POSIX), `_popen()` (Windows) | `Process.ExecProgress()` — commands with progress bar |
| `run_capture()` | `fork()+execvp()` with pipe (POSIX), `_popen()` (Windows) | `probe_codecs()`, `probe_duration_ms()`, `probe_resolution()` |
| `run_shell()` | `std::system()` — **shell, glob expansion** | `build.carbon` only (hardcoded strings, no user input) |

`run_shell()` is intentionally shell-based for build tool glob expansion. All callers use hardcoded command strings. No user input reaches `run_shell()`.

## Code review checklist (from skill)

- [ ] no `fork+exec` call site outside `src/core/ffi_helper.hpp` (process::run_str)
- [ ] `Validate.*` invoked before any `builder.Add(Constants.FlagInput, input)`
- [ ] `grep -n 'system(' src` → only in `ffi_helper.hpp` (build tool only, via `run_shell`)
- [ ] `grep -n 'run_str(' src` → only in `ffi_helper.hpp` and `Process.carbon`
- [ ] no secrets/env-dump in help output or `--debug`
- [ ] `validate_path()` rejects injection chars (`'`, `\n`, `\r`, `\0`)
- [ ] `escape_drawtext()` covers `: ' \ ; % [ ]`
- [ ] concat list builders escape `'` in filenames

# Changelog

## [0.2.6] - 2026-09-02

### Changed

- **OOP refactoring**: new `CommandContext` class with `ref self` for mutation, `DryRun` helper, tuple returns — eliminates boilerplate across 17 CLI files, removed unused `Validate` imports from 13 files.


## [0.2.5] - 2026-09-01

### Added

- **`--no-subs` flag**: strips subtitle tracks from `compress` and `convert`. Auto-applied for `--web`/`--mobile` presets.
- **`std::format`**: replaced `std::to_string`/`snprintf`/string concat with `std::format` across probe helpers, filter builders, and atempo chain.
- **`DefaultVideoEncoder()`**: extracted magic `"libx264"` to Constants.carbon (check-no-magic clean).

### Removed

- **Dead C++ helpers**: `probe_codecs()`, `probe_resolution()`, `probe_duration_str()` (defined but never called).

### Changed

- **Validate.CheckInput()**: replaces 10-line path validation block in 17 CLI files.
- **Process.ExecAndReport() / ExecSimple()**: replaces 3-line exec + print pattern.

### Fixed

- **Completions**: removed phantom `--to`/`--half`/`--double`/`--set`/`--duration`; added `--no-subs` on convert/compress, `--flip` on rotate.
- **`test_dry_run.sh`**: removed mid-script `Results: 29`, added final `Results: 58`.
- **`test_security.sh`**: removed mid-script `Results: 51`, added final `Results: 54`.
- **README.md**: fixed stale test counts to 150 (58+54+14+24).
- **`make test` target**: runs full shell test suite (dry-run, security, exit codes, smoke).
- **Test fixtures**: added `in_h265.mp4`, `in_hd.mp4` (1280x720), `in_odd.mp4` for codec/dimension/resize testing.
- **C++ preset builder** (`build_compress_args()`): single C++ call replaces 40+ Carbon `AddFlagValue` calls for codec/crf/preset selection.
- **STL container refactoring**: `video_compatible()`, `audio_compatible()`, `format_for_ext()` rewritten with `std::unordered_map`/`std::unordered_set` instead of if-chains.

### Removed

- **19 dead constants** from `Constants.carbon`: preset-specific crf/preset/audio-br constants now handled by C++ `build_compress_args()`.

### Fixed

- **`thumbnail --time` test**: `check_contains` was checking the wrong `$OUT` (overwritten by `--webp` test).

## [0.2.4] - 2026-09-01

### Added

- **crop subcommand**: crop video to region (`--width`, `--height`, `--x`, `--y`).
- **WebP animated thumbnail**: `--webp` flag for `thumbnail` (uses `libwebp_anim`).
- **JPEG XL compression**: `--jxl` flag for `compress` (uses `libjxl`).
- **Compiler hardening**: `-Wall -Wextra -fstack-protector-strong -D_FORTIFY_SOURCE=2` in `ArgsBuilder.StartBuild()` and Makefile.
- **`carbon clang` docs**: documented standalone C++ compilation, `-fexperimental-library`, `<filesystem>`/`<memory_resource>` support.
- **Smart remux**: `convert` auto-copies compatible streams (h264+aac mp4→mkv = instant copy).
- **Per-format presets**: `--web`/`--mobile`/`--streaming` adapt codec to output format (.webm → VP9).
- **Video normalization**: auto-adds yuv420p + even dimensions for h264/h265 output.
- **Audio downmix**: `--web`/`--mobile` auto-downmix to stereo when source > 2 channels.
- **Container compatibility tables**: full codec compatibility for mp4, matroska, webm, mov, mpegts.
- **colordetect subcommand**: detect video color properties (range, alpha mode).
- **crop tests**: dry-run (2 checks) + security (missing input, valid input).
- **License headers**: MIT SPDX headers on all 24 source files.
- **`run_capture_stderr()`**: C++ helper for capturing both stdout and stderr from commands.
- **`Process.RunCapture()`**: Carbon wrapper for `run_capture` (stdout only).

### Fixed

- **`argv_run_exec()` round-trip bug**: `argv_build_cmd()` added shell quotes, `tokenize()` didn't parse them → `execvp` received literal `"` characters. Fixed: pass `g_tokens` directly to `execvp`. Also fixed `tokenize()` to handle shell quotes for `Process.Exec()` path.
- **`convert --codec h265`**: mapped to `hevc` (ffmpeg auto-selects `libx265`).
- **SVT-AV1 `-preset`**: changed from string `"medium"` to integer `"8"` (SVT-AV1 requires integer -2..13).
- **`test_security.sh`**: moved `[ "$FAIL" = "0" ] || exit 1` to end of file — was silently skipping last 3 tests on any failure.
- **`scripts/debug.py`**: added `crop` and `colordetect` to `DRY_RUN_TESTS` (was 16, now 18).

### Fixed (prior)

- **`--web` preset missing faststart**: moved `-movflags +faststart` out of `--video-bitrate` block to apply for `--web`.
- **`write_temp_file` suffix**: `mkstemp` requires `XXXXXX` at end; create first, then `rename()` with suffix.
- **Convert.carbon raw `==`**: replaced string `==` with `Cpp.str_eq()` (Carbon operator== bug).
- **`ffi_helper.hpp` warnings**: fixed unused `suffix` parameter, unchecked `write()` return.

### Changed

- Test counts: 57 dry-run, 54 security, 14 exit, 3 progress, 24 smoke (152 total).

## [0.2.3] - 2026-09-01

### Added

- **AV1 preset**: `--av1` flag for `compress` (libsvtav1, CRF 30, medium preset).
- **Makefile**: auto-detects latest `carbon_toolchain-*`, bootstrap chain (`build.carbon` → `./build` → `easy-ffmpeg`), targets: `all`, `clean`, `fmt`, `docs`, `check`, `ci`, `once`.
- **.clang-format**: Google style, 100-col. `make fmt` runs both `carbon format` and `clang-format -i`.
- **Formatting rule** (RULES.md §7, AGENTS.md): run `make fmt` after every change.
- **Makefile bootstrap**: if `build.carbon` is modified, `make` rebuilds `./build` first. Direct `carbon build` without flags is now a documented anti-pattern.

### Fixed

- Removed unused `#include <algorithm>` from `ffi_helper.hpp`.
- Fixed stale `class Builder` references in ARCHITECTURE.md, PLAN.md (now module-level functions).
- Fixed data flow example to match actual ArgsBuilder API.

### Changed

- Updated test counts: 54 dry-run checks, 190 total tests.
- Applied `carbon format` to all `.carbon` files.

## [0.2.2] - 2026-09-01

### Changed

- **ArgsBuilder helpers**: `StartFfmpeg()` (Clear+FfmpegBin+FlagOverwrite), `StartBuild(tc)`, `AddMany` through `AddMany5` reduce boilerplate across 14 CLI files and build.carbon.
- **Resize dedup**: extracted `RunWithFilter()` — 5 identical code paths collapsed to one.
- **ffi_helper dedup**: extracted `probe_stream_codec()` (dedup `probe_codecs`), `escape_concat_entry()` (dedup concat builders), `probe_duration_str()` reuses `probe_duration_ms()`.
- **build.carbon**: extracted `VerboseCmd()`, uses `AddMany3/4/5` and `StartBuild()`.
- **README.md**: fixed toolchain date, test counts, inaccurate C++ interop claims.
- **docs/CARBON_TOOLCHAIN.md**: added empirical feature test results (OOP, Range, match, C++ interop, Optional).
- **AGENTS.md**: added toolchain features tested section (2026-09-01).

### Fixed

- `resolve_carbon()` hardcoded toolchain path `2026.08.29` — now `2026.09.01`.

## [0.2.1] - 2026-09-01

### Fixed

- **Exit code propagation**: Trim, Resize, AudioExtract, Convert now return
  ffmpeg's actual exit code instead of always reporting success.
- **argv_run_exec string round-trip**: tokens now pass directly to fork+execvp
  without string serialization, preventing corruption of paths with spaces.
- **Constant consolidation**: removed duplicates (CodecCopy/FlagCodecCopy,
  CodecNameH264/CodecH264, CodecNameAac/CodecAac), fixed typo FlagSsseof.
- **operator== workaround**: added `str_eq`/`str_ne`/`i_to_str` C++ helpers;
  replaced all string `==`/`!=` in 16 CLI files (51 call sites) to work around
  Carbon nightly operator== lowering bug (persists through 0.9.01).
- **Compress exit code bug**: `return Constants.ExitSuccess()` → `return rc`.

### Security

- Added 50 TDD security tests: path traversal, injection characters,
  device files, missing args, valid inputs, help flags.
- `FlagMap()` now used (was defined but unused, 8 hardcoded replacements).
- Added constants for `-af`, `-vframes`, `-safe` flags.

### Changed

- Upgraded toolchain from 0.8.29 to 0.9.01 (`scripts/env.sh`, `AGENTS.md`).
- Upgraded build from C++17 to C++23.
- `std::format` replaces `snprintf` in `atempo_chain`.
- `std::from_chars` replaces `std::stol`/`std::stod` (zero-exception parsing).
- `std::ifstream` replaces `fopen`/`fgets`/`fclose` in `read_carbon_src`.
- `constexpr` on pure functions (`validate_numeric`, `stoi`).
- `[[nodiscard]]` on `argv_run_shell()` and `argv_run_exec()`.
- `std::string_view` params for `build_watermark_filter`, `build_rotate_filter`, `build_subtitle_filter`.
- Removed unused `<span>` include from `ffi_helper.hpp`.
- Gif.carbon simplified: uses int constants directly (no stoi conversion).
- Magic number constants added: `NotFoundIndex()`, `SafeZero()`, `VframesOne()`, `DefaultGifFps()`, `DefaultGifWidth()`, `DefaultThumbnailTime()`.
- 10 CLI files: `Add`+`Add` consolidated to `AddFlagValue`.
- Deleted stale `docs/TODO.md`, `docs/VERIFICATION.md`, `tests/test_new_dry_run.sh`.
- `tests/fixtures/in.srt` created for subtitle dry-run tests.
- `scripts/debug.py` rewritten: 8 test sections, `--section`/`--json` flags.

## [0.2.0] - 2026-09-01

### Added

- **16 subcommands**: convert, compress, trim, resize, audio-extract, probe,
  concat, gif, thumbnail, speed, rotate, watermark, subtitle, metadata,
  normalize, replace-audio.
- Progress bar for encoding subcommands (parses ffmpeg `out_time_ms`).
- Scale presets: `tiktok`, `instagram`, `youtube` (resize).
- Compress `--audio-codec`, `--video-bitrate`.
- Trim `--sseof` (offset from end).
- Shell completions for bash (all 16 commands).
- `--dry-run` prints exact ffmpeg argv without forking.
- ANSI color output for errors.
- `build.carbon` as single entry point (replaces shell scripts).
- `scripts/debug.py`: 18-check automated verification.
- `docs/SECURITY.md`: execution paths, code review checklist, injection-proofing.

### Security

- Shell injection fixed: all execution goes through `fork()+execvp()`
  via `ArgsBuilder.RunExec()`, no `system()` in Carbon code paths.
- Path traversal blocked: `validate_path()` rejects `..`, `'`, `\n`, `\r`, `\0`,
  non-regular files.
- Concat list filenames escaped (`'` -> `'\''`).
- Subtitle SRT paths escaped for ffmpeg filter syntax.
- Drawtext text escaped for `; % [ ]` in addition to `: ' \`.
- Double-quoted args escaped in shell command builder.

### Changed

- C++17 modernization of `ffi_helper.hpp`:
  - `<filesystem>`: `exists()`, `validate_path()`, `cwd()`, `remove_temp_file()`.
  - `<charconv>`: `stoi()`, `probe_duration_ms()` (no exceptions).
  - Extracted `tokenize()`/`to_argv()` helpers (dedup 3x fork code).
  - `string::reserve()` in hot builders.
  - `constexpr validate_numeric()`.
- Build checks (`check_no_magic`, `check_no_duplication`) are pure C++17
  no more `popen("grep ...")`.
- `Constants.carbon` reorganized with section headers.
- Removed unused `<algorithm>` include from `ffi_helper.hpp`.
- Removed 20 unused Carbon imports across 20 files.
- `run_shell` C-style wrapper and dead `run()` removed.
- `build.carbon` uses `ArgsBuilder.Clear/Add/RunShell` (no raw C++ calls).

### Fixed

- `Compress.carbon` magic literal `"-b:v"` -> `Constants.FlagVideoBitrate()`.
- `build.carbon` `--once` argument order (`--dry-run` after subcommand).
- Progress bar test pattern matching for `[###] 100%` output.
- Probe exit code propagation from ffprobe.

## [0.1.0] - 2026-08-29

### Added

- Initial scaffold: Carbon toolchain bootstrap, docs, scripts, tests.
- Core: `Constants.carbon`, `ArgsBuilder.carbon`, `Process.carbon`, `Validate.carbon`.
- 6 subcommands: convert, compress, trim, resize, audio-extract, probe.
- `--help`, `--version`, `-h`, `-v` flags.
- `--dry-run` mode.
- `check-no-magic` build gate (magic literals must live in `Constants.carbon`).

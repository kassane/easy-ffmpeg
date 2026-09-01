# Changelog

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

# Changelog

## [0.2.1] - 2026-09-01

### Fixed

- **Exit code propagation**: Trim, Resize, AudioExtract, Convert now return
  ffmpeg's actual exit code instead of always reporting success.
- **argv_run_exec string round-trip**: tokens now pass directly to fork+execvp
  without string serialization, preventing corruption of paths with spaces.
- **Constant consolidation**: removed duplicates (CodecCopy/FlagCodecCopy,
  CodecNameH264/CodecH264, CodecNameAac/CodecAac), fixed typo FlagSsseof.

### Security

- Added 50 TDD security tests: path traversal, injection characters,
  device files, missing args, valid inputs, help flags.
- `FlagMap()` now used (was defined but unused, 8 hardcoded replacements).
- Added constants for `-af`, `-vframes`, `-safe` flags.

### Changed

- Upgraded build from C++17 to C++23.
- `std::format` replaces `snprintf` in `atempo_chain`.
- `std::from_chars` replaces `std::stol`/`std::stod` (zero-exception parsing).
- `std::ifstream` replaces `fopen`/`fgets`/`fclose` in `read_carbon_src`.

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

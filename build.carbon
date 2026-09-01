// build.carbon — single build entry point.
// Build: carbon build build.carbon src/core/ArgsBuilder.carbon --output=build -- -std=c++23 -Isrc/core
// Usage: ./build [--once|--ci|--clean|--format|--check|--help|--version|-v]
import ArgsBuilder library "core/args";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr("\x1B[1m");
  Core.PrintStr("easy-ffmpeg build tool");
  Core.PrintStr("\x1B[0m\n");
  Core.PrintStr("Usage: ./build [command]\n");
  Core.PrintStr("\n");
  Core.PrintStr("  (none)   Build the project\n");
  Core.PrintStr("  --once   Build + verify (one-shot gate)\n");
  Core.PrintStr("  --ci     Full CI pipeline\n");
  Core.PrintStr("  --clean  Remove build artifacts\n");
  Core.PrintStr("  --format Format Carbon source files\n");
  Core.PrintStr("  --check  Validation checks only\n");
  Core.PrintStr("  --verbose  Show commands before running\n");
  Core.PrintStr("  -v, --version  Show version\n");
  Core.PrintStr("  -h, --help     Show this help\n");
}

fn Run() {
  Cpp.cli.capture();
  if (Cpp.cli.has_help() == 1 or Cpp.cli.has_flag("--version") == 1) {
    if (Cpp.cli.has_help() == 1) { ShowHelp(); }
    if (Cpp.cli.has_flag("--version") == 1) { Core.PrintStr("easy-ffmpeg build 0.2.1\n"); }
    Cpp.cli_exit(0);
    return;
  }

  var verbose: i32 = 0;
  if (Cpp.cli.has_flag("--verbose") == 1) { verbose = 1; }

  let tc: Cpp.std.string = Cpp.resolve_carbon();

  if (Cpp.cli.arg_matches(1, "--clean") == 1) {
    Core.PrintStr("Cleaning...\n");
    if (verbose == 1) { Core.PrintStr("$ rm -f easy-ffmpeg /tmp/easy-ffmpeg\n"); }
    ArgsBuilder.Clear();
    ArgsBuilder.Add(Cpp.strh.make("rm"));
    ArgsBuilder.Add(Cpp.strh.make("-f"));
    ArgsBuilder.Add(Cpp.strh.make("easy-ffmpeg"));
    ArgsBuilder.Add(Cpp.strh.make("/tmp/easy-ffmpeg"));
    ArgsBuilder.RunShell();
    Core.PrintStr("done\n");
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--format") == 1) {
    ArgsBuilder.Clear();
    ArgsBuilder.Add(tc);
    ArgsBuilder.Add(Cpp.strh.make("format"));
    ArgsBuilder.Add(Cpp.strh.make("src/**/*.carbon"));
    if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
    ArgsBuilder.RunShell();
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--check") == 1) {
    if (Cpp.build.check_no_magic() != 0) { Cpp.cli_exit(1); return; }
    if (Cpp.build.check_no_duplication() != 0) { Cpp.cli_exit(1); return; }
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--ci") == 1) {
    Core.PrintStr("[1/4] format\n");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(tc);
    ArgsBuilder.Add(Cpp.strh.make("format"));
    ArgsBuilder.Add(Cpp.strh.make("src/**/*.carbon"));
    if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
    ArgsBuilder.RunShell();
    Core.PrintStr("[2/4] check-no-magic\n");
    if (Cpp.build.check_no_magic() != 0) {
      Core.PrintStr("\x1B[31m[ci] FAILED\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("[3/4] check-no-duplication\n");
    if (Cpp.build.check_no_duplication() != 0) {
      Core.PrintStr("\x1B[31m[ci] FAILED\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("[4/4] build\n");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(tc);
    ArgsBuilder.Add(Cpp.strh.make("build"));
    ArgsBuilder.Add(Cpp.strh.make("src/main.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("src/core/*.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("src/cli/*.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("--output=easy-ffmpeg"));
    ArgsBuilder.Add(Cpp.strh.make("--"));
    ArgsBuilder.Add(Cpp.strh.make("-std=c++23"));
    ArgsBuilder.Add(Cpp.strh.make("-Isrc/core"));
    if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
    if (ArgsBuilder.RunShell() != 0) {
      Core.PrintStr("\x1B[31m[ci] FAILED\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("\x1B[32m[ci] ALL GREEN\x1B[0m\n");
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--once") == 1) {
    Core.PrintStr("Building...\n");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(tc);
    ArgsBuilder.Add(Cpp.strh.make("build"));
    ArgsBuilder.Add(Cpp.strh.make("src/main.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("src/core/*.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("src/cli/*.carbon"));
    ArgsBuilder.Add(Cpp.strh.make("--output=easy-ffmpeg"));
    ArgsBuilder.Add(Cpp.strh.make("--"));
    ArgsBuilder.Add(Cpp.strh.make("-std=c++23"));
    ArgsBuilder.Add(Cpp.strh.make("-Isrc/core"));
    if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
    if (ArgsBuilder.RunShell() != 0) {
      Core.PrintStr("\x1B[31m[red] build failed\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("Testing...\n");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(Cpp.strh.make("./easy-ffmpeg"));
    ArgsBuilder.Add(Cpp.strh.make("convert"));
    ArgsBuilder.Add(Cpp.strh.make("tests/fixtures/in.mp4"));
    ArgsBuilder.Add(Cpp.strh.make("/tmp/out.mp4"));
    ArgsBuilder.Add(Cpp.strh.make("--dry-run"));
    ArgsBuilder.RunShell();

    ArgsBuilder.Clear();
    ArgsBuilder.Add(Cpp.strh.make("./easy-ffmpeg"));
    ArgsBuilder.Add(Cpp.strh.make("compress"));
    ArgsBuilder.Add(Cpp.strh.make("tests/fixtures/in.mp4"));
    ArgsBuilder.Add(Cpp.strh.make("/tmp/out.mp4"));
    ArgsBuilder.Add(Cpp.strh.make("--web"));
    ArgsBuilder.Add(Cpp.strh.make("--dry-run"));
    ArgsBuilder.RunShell();
    Core.PrintStr("\x1B[32m[green] ok\x1B[0m\n");
    Cpp.cli_exit(0);
    return;
  }

  // Default: always rebuild
  Core.PrintStr("Building...\n");
  ArgsBuilder.Clear();
  ArgsBuilder.Add(tc);
  ArgsBuilder.Add(Cpp.strh.make("build"));
  ArgsBuilder.Add(Cpp.strh.make("src/main.carbon"));
  ArgsBuilder.Add(Cpp.strh.make("src/core/*.carbon"));
  ArgsBuilder.Add(Cpp.strh.make("src/cli/*.carbon"));
  ArgsBuilder.Add(Cpp.strh.make("--output=easy-ffmpeg"));
  ArgsBuilder.Add(Cpp.strh.make("--"));
  ArgsBuilder.Add(Cpp.strh.make("-std=c++23"));
  ArgsBuilder.Add(Cpp.strh.make("-Isrc/core"));
  if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
  let rc: i32 = ArgsBuilder.RunShell();
  if (rc == 0) { Core.PrintStr("\x1B[32m[green] build ok\x1B[0m\n"); }
  Cpp.cli_exit(rc);
}

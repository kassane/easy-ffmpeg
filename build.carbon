// build.carbon — single build entry point.
// Build: carbon build build.carbon --output=build -- -std=c++17 -Isrc/core
// Usage: ./build [--once|--ci|--clean|--format|--check|--help|--version|-v]
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
  if (Cpp.cli.has_help() == 1) {
    ShowHelp();
    Cpp.cli_exit(0);
    return;
  }
  if (Cpp.cli.has_flag("--version") == 1) {
    Core.PrintStr("easy-ffmpeg build 0.2.0\n");
    Cpp.cli_exit(0);
    return;
  }

  var verbose: i32 = 0;
  if (Cpp.cli.has_flag("--verbose") == 1) { verbose = 1; }

  let tc: Cpp.std.string = Cpp.resolve_carbon();
  let fmt: Cpp.std.string = Cpp.strh.concat3(tc, " format src/**/*.carbon", "");
  let bld: Cpp.std.string = Cpp.strh.concat3(tc,
    " build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=easy-ffmpeg -- -std=c++17 -Isrc/core", "");

  if (Cpp.cli.arg_matches(1, "--clean") == 1) {
    Core.PrintStr("Cleaning...\n");
    if (verbose == 1) { Core.PrintStr("$ rm -f easy-ffmpeg /tmp/easy-ffmpeg\n"); }
    Cpp.run_shell("rm -f easy-ffmpeg /tmp/easy-ffmpeg");
    Core.PrintStr("done\n");
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--format") == 1) {
    if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(fmt); Core.PrintStr("\n"); }
    Cpp.run_shell(fmt);
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
    Cpp.run_shell(fmt);
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
    if (Cpp.run_shell(bld) != 0) {
      Core.PrintStr("\x1B[31m[ci] FAILED\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("\x1B[32m[ci] ALL GREEN\x1B[0m\n");
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--once") == 1) {
    Core.PrintStr("Building...\n");
    if (Cpp.run_shell(bld) != 0) {
      Core.PrintStr("\x1B[31m[red] build failed\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("Testing...\n");
    Cpp.run_shell("./easy-ffmpeg --dry-run convert test.mp4 out.mp4");
    Cpp.run_shell("./easy-ffmpeg --dry-run compress test.mp4 out.mp4 --web");
    Core.PrintStr("\x1B[32m[green] ok\x1B[0m\n");
    Cpp.cli_exit(0);
    return;
  }

  // Default: always rebuild
  if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(bld); Core.PrintStr("\n"); }
  Core.PrintStr("Building...\n");
  let rc: i32 = Cpp.run_shell(bld);
  if (rc == 0) { Core.PrintStr("\x1B[32m[green] build ok\x1B[0m\n"); }
  Cpp.cli_exit(rc);
}

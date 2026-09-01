// build.carbon — single build entry point.
// Usage: ./build [--once|--ci|--clean|--format|--check|--help|--version|-v]
import ArgsBuilder library "core/args";
import Core library "io";
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

fn VerboseCmd(verbose: i32) {
  if (verbose == 1) { Core.PrintStr("$ "); Core.PrintStr(ArgsBuilder.ToSystemCmd()); Core.PrintStr("\n"); }
}

fn Run() {
  Cpp.cli.capture();
  if (Cpp.cli.has_help() == 1 or Cpp.cli.has_flag("--version") == 1) {
    if (Cpp.cli.has_help() == 1) { ShowHelp(); }
    if (Cpp.cli.has_flag("--version") == 1) { Core.PrintStr("easy-ffmpeg build 0.2.2\n"); }
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
    ArgsBuilder.AddMany4(Cpp.strh.make("rm"), Cpp.strh.make("-f"), Cpp.strh.make("easy-ffmpeg"), Cpp.strh.make("/tmp/easy-ffmpeg"));
    ArgsBuilder.RunShell();
    Core.PrintStr("done\n");
    Cpp.cli_exit(0);
    return;
  }

  if (Cpp.cli.arg_matches(1, "--format") == 1) {
    ArgsBuilder.Clear();
    ArgsBuilder.AddMany3(tc, Cpp.strh.make("format"), Cpp.strh.make("src/**/*.carbon"));
    VerboseCmd(verbose);
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
    ArgsBuilder.AddMany3(tc, Cpp.strh.make("format"), Cpp.strh.make("src/**/*.carbon"));
    VerboseCmd(verbose);
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
    ArgsBuilder.StartBuild(tc);
    VerboseCmd(verbose);
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
    ArgsBuilder.StartBuild(tc);
    VerboseCmd(verbose);
    if (ArgsBuilder.RunShell() != 0) {
      Core.PrintStr("\x1B[31m[red] build failed\x1B[0m\n");
      Cpp.cli_exit(1); return;
    }
    Core.PrintStr("Testing...\n");
    ArgsBuilder.Clear();
    ArgsBuilder.AddMany5(Cpp.strh.make("./easy-ffmpeg"), Cpp.strh.make("convert"), Cpp.strh.make("tests/fixtures/in.mp4"), Cpp.strh.make("/tmp/out.mp4"), Cpp.strh.make("--dry-run"));
    ArgsBuilder.RunShell();

    ArgsBuilder.Clear();
    ArgsBuilder.AddMany5(Cpp.strh.make("./easy-ffmpeg"), Cpp.strh.make("compress"), Cpp.strh.make("tests/fixtures/in.mp4"), Cpp.strh.make("/tmp/out.mp4"), Cpp.strh.make("--web"));
    ArgsBuilder.RunShell();
    Core.PrintStr("\x1B[32m[green] ok\x1B[0m\n");
    Cpp.cli_exit(0);
    return;
  }

  // Default: always rebuild
  Core.PrintStr("Building...\n");
  ArgsBuilder.StartBuild(tc);
  VerboseCmd(verbose);
  let rc: i32 = ArgsBuilder.RunShell();
  if (rc == 0) { Core.PrintStr("\x1B[32m[green] build ok\x1B[0m\n"); }
  Cpp.cli_exit(rc);
}

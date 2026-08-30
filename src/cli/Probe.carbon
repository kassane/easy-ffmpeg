package Probe library "cli/probe";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg probe <input>\n");
  Core.PrintStr("  --json       Output as JSON\n");
  Core.PrintStr("  --dry-run    Print ffprobe command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg probe video.mp4\n");
  Core.PrintStr("  easy-ffmpeg probe video.mp4 --json\n");
}

fn Run() -> i32 {
  if (Cpp.cli.has_help() == 1) { ShowHelp(); return Constants.ExitSuccess(); }
  if (Cpp.cli.positional_count() < 1) {
    Core.PrintStr(Cpp.color.red("error: need input file"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let input: Cpp.std.string = Cpp.cli.get_positional(0);
  let path_err: i32 = Validate.ValidatePath(input);
  if (path_err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (path_err == 2) {
    Core.PrintStr(Cpp.color.red("error: input file not found or not a regular file"));
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfprobeBin());
  ArgsBuilder.Add(Constants.FlagVerbosity());
  ArgsBuilder.Add(Constants.QuietValue());
  if (Cpp.cli.has_flag("--json") == 1) {
    ArgsBuilder.Add(Constants.FlagPrintFormat());
    ArgsBuilder.Add(Constants.JsonValue());
  }
  ArgsBuilder.Add(Constants.FlagShowStreams());
  ArgsBuilder.Add(input);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.Exec(cmd);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

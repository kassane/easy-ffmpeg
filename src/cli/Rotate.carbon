package Rotate library "cli/rotate";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg rotate <input> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --angle <90|180|270>   Rotate by degrees\n");
  Core.PrintStr("  --flip <h|v>           Flip horizontal or vertical\n");
  Core.PrintStr("  --dry-run              Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg rotate video.mp4 rotated.mp4 --angle 90\n");
  Core.PrintStr("  easy-ffmpeg rotate video.mp4 flipped.mp4 --flip h\n");
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
  let output: Cpp.std.string = Cpp.cli.get_positional(1);
  if (output == "") {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let angle: Cpp.std.string = Cpp.cli.get_flag_value("--angle");
  let flip: Cpp.std.string = Cpp.cli.get_flag_value("--flip");
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfmpegBin());
  ArgsBuilder.Add(Constants.FlagOverwrite());
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  if (angle != "") {
    if (angle != "90" and angle != "180" and angle != "270") {
      Core.PrintStr(Cpp.color.red("error: --angle must be 90, 180, or 270"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.build_rotate_filter(angle));
  } else if (flip == "h") {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.strh.make("hflip"));
  } else if (flip == "v") {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.strh.make("vflip"));
  } else {
    Core.PrintStr(Cpp.color.red("error: --angle or --flip required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

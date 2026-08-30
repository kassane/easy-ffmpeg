package Resize library "cli/resize";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg resize <input> [output]\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Scale presets:\n"));
  Core.PrintStr("  --scale hd       720p\n");
  Core.PrintStr("  --scale fullhd   1080p\n");
  Core.PrintStr("  --scale 2k       1440p\n");
  Core.PrintStr("  --scale retro    480p\n");
  Core.PrintStr("  --scale icon     240p\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Manual:\n"));
  Core.PrintStr("  --width <px>     Target width\n");
  Core.PrintStr("  --height <px>    Target height\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --scale hd\n");
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --width 320 --height 240\n");
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
  let scale: Cpp.std.string = Cpp.cli.get_flag_value("--scale");
  let w: Cpp.std.string = Cpp.cli.get_flag_value("--width");
  let h: Cpp.std.string = Cpp.cli.get_flag_value("--height");
  if (scale != "") {
    let h_str: Cpp.std.string = Cpp.scale_height(scale);
    if (h_str == "0") {
      Core.PrintStr(Cpp.color.red("error: unknown scale preset"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    let filter: Cpp.std.string = Cpp.strh.concat3("scale=-2:", h_str, "");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(Constants.FfmpegBin());
    ArgsBuilder.Add(Constants.FlagOverwrite());
    ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
    ArgsBuilder.Add(output);
  } else if (w != "") {
    if (h == "") {
      Core.PrintStr(Cpp.color.red("error: --height required with --width"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    let filter: Cpp.std.string = Cpp.strh.concat3("scale=", w, ":");
    let filter_full: Cpp.std.string = Cpp.strh.concat3(filter, h, "");
    ArgsBuilder.Clear();
    ArgsBuilder.Add(Constants.FfmpegBin());
    ArgsBuilder.Add(Constants.FlagOverwrite());
    ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter_full);
    ArgsBuilder.Add(output);
  } else {
    Core.PrintStr(Cpp.color.red("error: --scale or --width + --height required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return Constants.ExitSuccess();
}

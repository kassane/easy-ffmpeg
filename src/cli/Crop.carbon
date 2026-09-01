package Crop library "cli/crop";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg crop <input> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --width <px>   Crop width\n");
  Core.PrintStr("  --height <px>  Crop height\n");
  Core.PrintStr("  --x <px>       X offset (default: centered)\n");
  Core.PrintStr("  --y <px>       Y offset (default: centered)\n");
  Core.PrintStr("  --dry-run      Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg crop video.mp4 out.mp4 --width 640 --height 480\n");
  Core.PrintStr("  easy-ffmpeg crop video.mp4 out.mp4 --width 320 --height 240 --x 100 --y 50\n");
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
  if (Cpp.str_eq(output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let w_str: Cpp.std.string = Cpp.cli.get_flag_value("--width");
  let h_str: Cpp.std.string = Cpp.cli.get_flag_value("--height");
  if (Cpp.str_eq(w_str, "") or Cpp.str_eq(h_str, "")) {
    Core.PrintStr(Cpp.color.red("error: --width and --height required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  if (Cpp.validate_numeric(w_str) == 0 or Cpp.validate_numeric(h_str) == 0) {
    Core.PrintStr(Cpp.color.red("error: --width and --height must be numbers"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let w: i32 = Cpp.stoi(w_str);
  let h: i32 = Cpp.stoi(h_str);
  if (w <= 0 or h <= 0) {
    Core.PrintStr(Cpp.color.red("error: --width and --height must be > 0"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  var x: i32 = -1;
  var y: i32 = -1;
  let x_str: Cpp.std.string = Cpp.cli.get_flag_value("--x");
  let y_str: Cpp.std.string = Cpp.cli.get_flag_value("--y");
  if (Cpp.str_ne(x_str, "")) {
    if (Cpp.validate_numeric(x_str) == 0) {
      Core.PrintStr(Cpp.color.red("error: --x must be a number"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    x = Cpp.stoi(x_str);
  }
  if (Cpp.str_ne(y_str, "")) {
    if (Cpp.validate_numeric(y_str) == 0) {
      Core.PrintStr(Cpp.color.red("error: --y must be a number"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    y = Cpp.stoi(y_str);
  }
  // default: center crop
  if (x < 0) { x = 0; }
  if (y < 0) { y = 0; }
  let filter: Cpp.std.string = Cpp.build_crop_filter(w, h, x, y);
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

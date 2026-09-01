// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Gif library "cli/gif";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg gif <input> <output.gif>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --fps <n>       Frames per second (default: 15)\n");
  Core.PrintStr("  --width <px>    Output width (default: 480)\n");
  Core.PrintStr("  --dry-run       Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg gif video.mp4 anim.gif\n");
  Core.PrintStr("  easy-ffmpeg gif video.mp4 anim.gif --fps 10 --width 320\n");
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
  let fps_str: Cpp.std.string = Cpp.cli.get_flag_value("--fps");
  let width_str: Cpp.std.string = Cpp.cli.get_flag_value("--width");
  var fps: i32 = Constants.DefaultGifFps();
  var width: i32 = Constants.DefaultGifWidth();
  if (Cpp.str_ne(fps_str, "")) {
    if (Cpp.validate_numeric(fps_str) == 0) {
      Core.PrintStr(Cpp.color.red("error: --fps must be a number"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    fps = Cpp.stoi(fps_str);
    if (fps <= 0) {
      Core.PrintStr(Cpp.color.red("error: --fps must be > 0"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
  }
  if (Cpp.str_ne(width_str, "")) {
    if (Cpp.validate_numeric(width_str) == 0) {
      Core.PrintStr(Cpp.color.red("error: --width must be a number"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    width = Cpp.stoi(width_str);
    if (width <= 0) {
      Core.PrintStr(Cpp.color.red("error: --width must be > 0"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
  }
  let filter: Cpp.std.string = Cpp.build_gif_filter(fps, width);
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

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Gif library "cli/gif";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

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
  var ctx: Ctx.CommandContext = Ctx.CommandContext.Make();
  let rc: i32 = ctx.LoadInputOutput();
  if (rc != 0) { return rc; }
  let rc2: i32 = ctx.CheckOutput();
  if (rc2 != 0) { return rc2; }
  if (Cpp.str_eq(ctx.output, "")) {
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
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

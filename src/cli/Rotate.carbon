// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Rotate library "cli/rotate";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

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
  let angle: Cpp.std.string = Cpp.cli.get_flag_value("--angle");
  let flip: Cpp.std.string = Cpp.cli.get_flag_value("--flip");
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  if (Cpp.str_ne(angle, "")) {
    if (Cpp.str_ne(angle, "90") and Cpp.str_ne(angle, "180") and Cpp.str_ne(angle, "270")) {
      Core.PrintStr(Cpp.color.red("error: --angle must be 90, 180, or 270"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.build_rotate_filter(angle));
  } else if (Cpp.str_eq(flip, "h")) {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.strh.make("hflip"));
  } else if (Cpp.str_eq(flip, "v")) {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Cpp.strh.make("vflip"));
  } else {
    Core.PrintStr(Cpp.color.red("error: --angle or --flip required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

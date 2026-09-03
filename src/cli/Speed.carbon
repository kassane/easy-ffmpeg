// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Speed library "cli/speed";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg speed <input> <output> --factor <n>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --factor <n>   Speed factor (0.5=half, 2.0=double)\n");
  Core.PrintStr("  --dry-run      Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg speed video.mp4 fast.mp4 --factor 2.0\n");
  Core.PrintStr("  easy-ffmpeg speed video.mp4 slow.mp4 --factor 0.5\n");
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
  let factor: Cpp.std.string = Cpp.cli.get_flag_value("--factor");
  if (Cpp.str_eq(factor, "")) {
    Core.PrintStr(Cpp.color.red("error: --factor required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  if (Cpp.validate_numeric(factor) == 0) {
    Core.PrintStr(Cpp.color.red("error: --factor must be a number"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let filter_complex: Cpp.std.string = Cpp.build_speed_filter_complex(factor);
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilterComplex(), filter_complex);
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("[v]"));
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("[a]"));
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

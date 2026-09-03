// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Subtitle library "cli/subtitle";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg subtitle <input> <output> --file <subs.srt>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --file <srt>   Subtitle file (SRT format)\n");
  Core.PrintStr("  --dry-run      Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg subtitle video.mp4 out.mp4 --file subs.srt\n");
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
  let srt: Cpp.std.string = Cpp.cli.get_flag_value("--file");
  if (Cpp.str_eq(srt, "")) {
    Core.PrintStr(Cpp.color.red("error: --file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let srt_err: i32 = Validate.ValidatePath(srt);
  if (srt_err == 1) {
    Core.PrintStr(Cpp.color.red("error: subtitle path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (srt_err == 2) {
    Core.PrintStr(Cpp.color.red("error: subtitle file not found: "));
    Core.PrintStr(srt);
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  let filter: Cpp.std.string = Cpp.build_subtitle_filter(srt);
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Trim library "cli/trim";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg trim <input> <output>\n");
  Core.PrintStr("  --start <time>     Start time (HH:MM:SS or seconds)\n");
  Core.PrintStr("  --duration <time>  Duration to extract\n");
  Core.PrintStr("  --end <time>       End time\n");
  Core.PrintStr("  --sseof <sec>      Start from last N seconds\n");
  Core.PrintStr("  --copy             Stream copy (no re-encode)\n");
  Core.PrintStr("  --dry-run          Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg trim video.mp4 clip.mp4 --start 00:01:00 --duration 30\n");
  Core.PrintStr("  easy-ffmpeg trim video.mp4 clip.mp4 --start 0 --end 10 --copy\n");
}

fn Run() -> i32 {
  if (Cpp.cli.has_help() == 1) { ShowHelp(); return Constants.ExitSuccess(); }
  var ctx: Ctx.CommandContext = Ctx.CommandContext.Make();
  let rc: i32 = ctx.LoadInputOutput();
  if (rc != 0) { return rc; }
  let rc2: i32 = ctx.CheckOutput();
  if (rc2 != 0) { return rc2; }
  // Validate trim options
  let duration: Cpp.std.string = Cpp.cli.get_flag_value("--duration");
  let end: Cpp.std.string = Cpp.cli.get_flag_value("--end");
  if (Cpp.str_ne(duration, "") and Cpp.str_ne(end, "")) {
    Core.PrintStr(Cpp.color.red("error: cannot use both --end and --duration. Pick one."));
    Core.PrintStr("\n");
    return Constants.ExitUsage();
  }
  ArgsBuilder.StartFfmpeg();
  let sseof: Cpp.std.string = Cpp.cli.get_flag_value("--sseof");
  if (Cpp.str_ne(sseof, "")) { ArgsBuilder.AddFlagValue(Constants.FlagSseof(), sseof); }
  let start: Cpp.std.string = Cpp.cli.get_flag_value("--start");
  if (Cpp.str_ne(start, "")) { ArgsBuilder.AddFlagValue(Constants.FlagStart(), start); }
  if (Cpp.str_ne(duration, "")) { ArgsBuilder.AddFlagValue(Constants.FlagDuration(), duration); }
  else if (Cpp.str_ne(end, "")) { ArgsBuilder.AddFlagValue(Constants.FlagTo(), end); }
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  if (Cpp.cli.has_flag("--copy") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
  }
  if (Cpp.str_eq(ctx.output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Probe library "cli/probe";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

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
  var ctx: Ctx.CommandContext = Ctx.CommandContext.Make();
  let rc: i32 = ctx.LoadInput(1);
  if (rc != 0) { return rc; }
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfprobeBin());
  ArgsBuilder.AddFlagValue(Constants.FlagVerbosity(), Constants.QuietValue());
  if (Cpp.cli.has_flag("--json") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagPrintFormat(), Constants.JsonValue());
  }
  ArgsBuilder.Add(Constants.FlagShowStreams());
  ArgsBuilder.Add(ctx.input);
  return ctx.ExecSimple();
}

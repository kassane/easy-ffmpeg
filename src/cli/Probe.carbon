// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Probe library "cli/probe";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

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
  if (Cpp.cli.positional_count() < 1) {
    Core.PrintStr(Cpp.color.red("error: need input file"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let input: Cpp.std.string = Cpp.cli.get_positional(0);
  let check_rc: i32 = Validate.CheckInput(input);
  if (check_rc != 0) { return check_rc; }
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfprobeBin());
  ArgsBuilder.AddFlagValue(Constants.FlagVerbosity(), Constants.QuietValue());
  if (Cpp.cli.has_flag("--json") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagPrintFormat(), Constants.JsonValue());
  }
  ArgsBuilder.Add(Constants.FlagShowStreams());
  ArgsBuilder.Add(input);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecSimple(cmd);
}

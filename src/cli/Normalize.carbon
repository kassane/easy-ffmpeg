// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Normalize library "cli/normalize";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg normalize <input> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --dry-run    Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Description:\n"));
  Core.PrintStr("  Normalizes audio to -16 LUFS using loudnorm filter.\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg normalize podcast.mp4 loud.mp4\n");
  Core.PrintStr("  easy-ffmpeg normalize audio.wav normalized.wav\n");
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
  let output: Cpp.std.string = Cpp.cli.get_positional(1);
  if (Cpp.str_eq(output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let filter: Cpp.std.string = Cpp.build_normalize_filter();
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagAudioFilter(), filter);
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecAndReport(cmd, input);
}

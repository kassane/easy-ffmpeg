// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Speed library "cli/speed";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

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
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilterComplex(), filter_complex);
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("[v]"));
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("[a]"));
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecAndReport(cmd, input);
}

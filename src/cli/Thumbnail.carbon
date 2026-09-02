// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Thumbnail library "cli/thumbnail";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg thumbnail <input> <output.jpg>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --time <HH:MM:SS>  Timestamp (default: 00:00:05)\n");
  Core.PrintStr("  --every <n>        Extract every N seconds (fps=1/N)\n");
  Core.PrintStr("  --dry-run          Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg thumbnail video.mp4 thumb.jpg\n");
  Core.PrintStr("  easy-ffmpeg thumbnail video.mp4 thumb.jpg --time 00:01:30\n");
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
  let time: Cpp.std.string = Cpp.cli.get_flag_value("--time");
  let every: Cpp.std.string = Cpp.cli.get_flag_value("--every");
  let webp: i32 = Cpp.cli.has_flag("--webp");
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  if (Cpp.str_ne(every, "")) {
    if (Cpp.validate_numeric(every) == 0) {
      Core.PrintStr(Cpp.color.red("error: --every must be a number"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    let every_val: i32 = Cpp.stoi(every);
    if (every_val <= 0) {
      Core.PrintStr(Cpp.color.red("error: --every must be > 0"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    let filter: Cpp.std.string = Cpp.build_thumbnail_filter(every_val);
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  } else {
    if (Cpp.str_eq(time, "")) {
      ArgsBuilder.AddFlagValue(Constants.FlagStart(), Cpp.strh.make(Constants.DefaultThumbnailTime()));
    } else {
      ArgsBuilder.AddFlagValue(Constants.FlagStart(), time);
    }
    ArgsBuilder.AddFlagValue(Constants.FlagVframes(), Cpp.strh.make(Constants.VframesOne()));
  }
  if (webp == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Cpp.strh.make("libwebp_anim"));
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecSimple(cmd);
}

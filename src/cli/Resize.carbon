// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Resize library "cli/resize";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg resize <input> [output]\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Scale presets:\n"));
  Core.PrintStr("  --scale hd       720p\n");
  Core.PrintStr("  --scale fullhd   1080p\n");
  Core.PrintStr("  --scale 2k       1440p\n");
  Core.PrintStr("  --scale retro    480p\n");
  Core.PrintStr("  --scale icon     240p\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Social presets:\n"));
  Core.PrintStr("  --scale tiktok     1080x1920\n");
  Core.PrintStr("  --scale instagram  1080x1080\n");
  Core.PrintStr("  --scale youtube    1920x1080\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Manual:\n"));
  Core.PrintStr("  --width <px>     Target width\n");
  Core.PrintStr("  --height <px>    Target height\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --scale hd\n");
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --width 320 --height 240\n");
}

// Build the common ffmpeg command for a scale filter and execute/dry-run.
fn RunWithFilter(filter: Cpp.std.string, input: Cpp.std.string, output: Cpp.std.string) -> i32 {
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecAndReport(cmd, input);
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
  let scale: Cpp.std.string = Cpp.cli.get_flag_value("--scale");
  let w: Cpp.std.string = Cpp.cli.get_flag_value("--width");
  let h: Cpp.std.string = Cpp.cli.get_flag_value("--height");
  if (Cpp.str_eq(scale, "tiktok")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleTiktok(), ""), input, output);
  } else if (Cpp.str_eq(scale, "instagram")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleInstagram(), ""), input, output);
  } else if (Cpp.str_eq(scale, "youtube")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleYoutube(), ""), input, output);
  } else if (Cpp.str_ne(scale, "")) {
    let h_str: Cpp.std.string = Cpp.scale_height(scale);
    if (Cpp.str_eq(h_str, "0")) {
      Core.PrintStr(Cpp.color.red("error: unknown scale preset"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    return RunWithFilter(Cpp.strh.concat3("scale=-2:", h_str, ""), input, output);
  } else if (Cpp.str_ne(w, "")) {
    if (Cpp.str_eq(h, "")) {
      Core.PrintStr(Cpp.color.red("error: --height required with --width"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    return RunWithFilter(Cpp.strh.concat3(Cpp.strh.concat3("scale=", w, ":"), h, ""), input, output);
  }
  Core.PrintStr(Cpp.color.red("error: --scale or --width + --height required"));
  Core.PrintStr("\n");
  return Constants.ExitFailure();
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Resize library "cli/resize";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

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
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Aspect ratio:\n"));
  Core.PrintStr("  --aspect <name>  wide, 4:3, 8:7, square, tiktok\n");
  Core.PrintStr("  --crop           Crop instead of pad (with --aspect)\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --scale hd\n");
  Core.PrintStr("  easy-ffmpeg resize video.mp4 out.mp4 --width 320 --height 240\n");
}

// Build the common ffmpeg command for a scale filter and execute/dry-run.
fn RunWithFilter(filter: Cpp.std.string, ctx: Ctx.CommandContext) -> i32 {
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
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
  let scale: Cpp.std.string = Cpp.cli.get_flag_value("--scale");
  let w: Cpp.std.string = Cpp.cli.get_flag_value("--width");
  let h: Cpp.std.string = Cpp.cli.get_flag_value("--height");
  if (Cpp.str_eq(scale, "tiktok")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleTiktok(), ""), ctx);
  } else if (Cpp.str_eq(scale, "instagram")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleInstagram(), ""), ctx);
  } else if (Cpp.str_eq(scale, "youtube")) {
    return RunWithFilter(Cpp.strh.concat3("scale=", Constants.ScaleYoutube(), ""), ctx);
  } else if (Cpp.str_ne(scale, "")) {
    let h_str: Cpp.std.string = Cpp.scale_height(scale);
    if (Cpp.str_eq(h_str, "0")) {
      Core.PrintStr(Cpp.color.red("error: unknown scale preset"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    return RunWithFilter(Cpp.strh.concat3("scale=-2:", h_str, ""), ctx);
  } else if (Cpp.str_ne(w, "")) {
    if (Cpp.str_eq(h, "")) {
      Core.PrintStr(Cpp.color.red("error: --height required with --width"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    return RunWithFilter(Cpp.strh.concat3(Cpp.strh.concat3("scale=", w, ":"), h, ""), ctx);
  }
  // Aspect ratio mode (--aspect without --scale/--width)
  let aspect: Cpp.std.string = Cpp.cli.get_flag_value("--aspect");
  if (Cpp.str_ne(aspect, "")) {
    let crop: i32 = Cpp.cli.has_flag("--crop");
    let filter: Cpp.std.string = Cpp.build_aspect_filter(aspect, crop);
    if (Cpp.str_eq(filter, "")) {
      Core.PrintStr(Cpp.color.red("error: unknown aspect ratio. Valid: wide, 4:3, 8:7, square, tiktok"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    return RunWithFilter(filter, ctx);
  }
  Core.PrintStr(Cpp.color.red("error: --scale, --width + --height, or --aspect required"));
  Core.PrintStr("\n");
  return Constants.ExitFailure();
}

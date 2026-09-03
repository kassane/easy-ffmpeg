// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Metadata library "cli/metadata";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg metadata <input> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --strip           Remove all metadata\n");
  Core.PrintStr("  --title <text>    Set title metadata\n");
  Core.PrintStr("  --artist <text>   Set artist metadata\n");
  Core.PrintStr("  --dry-run         Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg metadata video.mp4 clean.mp4 --strip\n");
  Core.PrintStr("  easy-ffmpeg metadata video.mp4 tagged.mp4 --title \"My Video\"\n");
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
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  if (Cpp.cli.has_flag("--strip") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagMapMetadata(), Cpp.strh.make("-1"));
  } else {
    let title: Cpp.std.string = Cpp.cli.get_flag_value("--title");
    let artist: Cpp.std.string = Cpp.cli.get_flag_value("--artist");
    if (Cpp.str_ne(title, "")) {
      ArgsBuilder.AddFlagValue(Constants.FlagMetadataTitle(), Cpp.strh.concat3("title=", title, ""));
    }
    if (Cpp.str_ne(artist, "")) {
      ArgsBuilder.AddFlagValue(Constants.FlagMetadataTitle(), Cpp.strh.concat3("artist=", artist, ""));
    }
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.ExecSimple();
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Metadata library "cli/metadata";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

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
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
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
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecSimple(cmd);
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package ReplaceAudio library "cli/replaceaudio";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg replace-audio <video> <output> --audio <audio.mp3>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --audio <file>   Replacement audio file\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg replace-audio video.mp4 out.mp4 --audio music.mp3\n");
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
  let audio: Cpp.std.string = Cpp.cli.get_flag_value("--audio");
  if (Cpp.str_eq(audio, "")) {
    Core.PrintStr(Cpp.color.red("error: --audio required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let a_err: i32 = Validate.ValidatePath(audio);
  if (a_err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (a_err == 2) {
    Core.PrintStr(Cpp.color.red("error: audio file not found or not a regular file"));
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), audio);
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("0:v"));
  ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("1:a"));
  ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
  ArgsBuilder.Add(Constants.FlagShortest());
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

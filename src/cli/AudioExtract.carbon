// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package AudioExtract library "cli/audioextract";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg audio-extract <input> <output>\n");
  Core.PrintStr("  --codec <codec>  Audio codec (libmp3lame, libopus, copy)\n");
  Core.PrintStr("  --bitrate <br>   Audio bitrate (128k, 192k, 320k)\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg audio-extract video.mp4 audio.mp3\n");
  Core.PrintStr("  easy-ffmpeg audio-extract video.mp4 audio.ogg --codec libopus\n");
}

fn Run() -> i32 {
  if (Cpp.cli.has_help() == 1) { ShowHelp(); return Constants.ExitSuccess(); }
  var ctx: Ctx.CommandContext = Ctx.CommandContext.Make();
  let rc: i32 = ctx.LoadInputOutput();
  if (rc != 0) { return rc; }
  let rc2: i32 = ctx.CheckOutput();
  if (rc2 != 0) { return rc2; }
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.Add(Constants.FlagVn());
  let codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (Cpp.str_ne(codec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), codec);
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.CodecLibmp3lame());
  }
  let bitrate: Cpp.std.string = Cpp.cli.get_flag_value("--bitrate");
  if (Cpp.str_ne(bitrate, "")) { ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), bitrate); }
  if (Cpp.str_eq(ctx.output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

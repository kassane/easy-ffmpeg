// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package AudioExtract library "cli/audioextract";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

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
  if (Cpp.cli.positional_count() < 1) {
    Core.PrintStr(Cpp.color.red("error: need input file"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let input: Cpp.std.string = Cpp.cli.get_positional(0);
  let check_rc: i32 = Validate.CheckInput(input);
  if (check_rc != 0) { return check_rc; }
  let output: Cpp.std.string = Cpp.cli.get_positional(1);
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.Add(Constants.FlagVn());
  let codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (Cpp.str_ne(codec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), codec);
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.CodecLibmp3lame());
  }
  let bitrate: Cpp.std.string = Cpp.cli.get_flag_value("--bitrate");
  if (Cpp.str_ne(bitrate, "")) { ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), bitrate); }
  if (Cpp.str_eq(output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecAndReport(cmd, input);
}

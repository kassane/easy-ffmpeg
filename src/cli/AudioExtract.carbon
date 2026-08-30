package AudioExtract library "cli/audioextract";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

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
  let path_err: i32 = Validate.ValidatePath(input);
  if (path_err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (path_err == 2) {
    Core.PrintStr(Cpp.color.red("error: input file not found or not a regular file"));
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  let output: Cpp.std.string = Cpp.cli.get_positional(1);
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfmpegBin());
  ArgsBuilder.Add(Constants.FlagOverwrite());
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.Add(Constants.FlagVn());
  let codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (codec != "") {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), codec);
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.CodecLibmp3lame());
  }
  let bitrate: Cpp.std.string = Cpp.cli.get_flag_value("--bitrate");
  if (bitrate != "") { ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), bitrate); }
  if (output == "") {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return Constants.ExitSuccess();
}

package ReplaceAudio library "cli/replaceaudio";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

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
  if (Cpp.cli.positional_count() < 1) {
    Core.PrintStr(Cpp.color.red("error: need video input file"));
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
    Core.PrintStr(Cpp.color.red("error: video input not found or not a regular file"));
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  let output: Cpp.std.string = Cpp.cli.get_positional(1);
  if (output == "") {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let audio: Cpp.std.string = Cpp.cli.get_flag_value("--audio");
  if (audio == "") {
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
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfmpegBin());
  ArgsBuilder.Add(Constants.FlagOverwrite());
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), audio);
  ArgsBuilder.Add(Cpp.strh.make("-map"));
  ArgsBuilder.Add(Cpp.strh.make("0:v"));
  ArgsBuilder.Add(Cpp.strh.make("-map"));
  ArgsBuilder.Add(Cpp.strh.make("1:a"));
  ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
  ArgsBuilder.Add(Constants.FlagShortest());
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

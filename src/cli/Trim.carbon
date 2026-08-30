package Trim library "cli/trim";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg trim <input> <output>\n");
  Core.PrintStr("  --start <time>     Start time (HH:MM:SS or seconds)\n");
  Core.PrintStr("  --duration <time>  Duration to extract\n");
  Core.PrintStr("  --end <time>       End time\n");
  Core.PrintStr("  --copy             Stream copy (no re-encode)\n");
  Core.PrintStr("  --dry-run          Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg trim video.mp4 clip.mp4 --start 00:01:00 --duration 30\n");
  Core.PrintStr("  easy-ffmpeg trim video.mp4 clip.mp4 --start 0 --end 10 --copy\n");
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
  let start: Cpp.std.string = Cpp.cli.get_flag_value("--start");
  if (start != "") { ArgsBuilder.Add(Constants.FlagStart()); ArgsBuilder.Add(start); }
  let duration: Cpp.std.string = Cpp.cli.get_flag_value("--duration");
  let end: Cpp.std.string = Cpp.cli.get_flag_value("--end");
  if (duration != "") { ArgsBuilder.Add(Constants.FlagDuration()); ArgsBuilder.Add(duration); }
  else if (end != "") { ArgsBuilder.Add(Constants.FlagTo()); ArgsBuilder.Add(end); }
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  if (Cpp.cli.has_flag("--copy") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
  }
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

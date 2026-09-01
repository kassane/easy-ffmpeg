package Speed library "cli/speed";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import ArgsBuilder library "core/args";
import Process library "core/process";
import Validate library "core/validate";
import Constants library "core/constants";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg speed <input> <output> --factor <n>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --factor <n>   Speed factor (0.5=half, 2.0=double)\n");
  Core.PrintStr("  --dry-run      Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg speed video.mp4 fast.mp4 --factor 2.0\n");
  Core.PrintStr("  easy-ffmpeg speed video.mp4 slow.mp4 --factor 0.5\n");
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
  if (output == "") {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let factor: Cpp.std.string = Cpp.cli.get_flag_value("--factor");
  if (factor == "") {
    Core.PrintStr(Cpp.color.red("error: --factor required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  if (Cpp.validate_numeric(factor) == 0) {
    Core.PrintStr(Cpp.color.red("error: --factor must be a number"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let filter_complex: Cpp.std.string = Cpp.build_speed_filter_complex(factor);
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfmpegBin());
  ArgsBuilder.Add(Constants.FlagOverwrite());
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  ArgsBuilder.AddFlagValue(Constants.FlagFilterComplex(), filter_complex);
  ArgsBuilder.Add(Cpp.strh.make("-map"));
  ArgsBuilder.Add(Cpp.strh.make("[v]"));
  ArgsBuilder.Add(Cpp.strh.make("-map"));
  ArgsBuilder.Add(Cpp.strh.make("[a]"));
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

package Concat library "cli/concat";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg concat <input1> <input2> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --copy          Stream copy (no re-encode, fast)\n");
  Core.PrintStr("  --codec <c>     Video codec for re-encode\n");
  Core.PrintStr("  --dry-run       Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg concat a.mp4 b.mp4 merged.mp4 --copy\n");
  Core.PrintStr("  easy-ffmpeg concat a.mp4 b.mp4 out.mp4 --codec h264\n");
}

fn Run() -> i32 {
  if (Cpp.cli.has_help() == 1) { ShowHelp(); return Constants.ExitSuccess(); }
  let pc: i32 = Cpp.cli.positional_count();
  if (pc < 3) {
    Core.PrintStr(Cpp.color.red("error: need 2 inputs + output"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let input1: Cpp.std.string = Cpp.cli.get_positional(0);
  let input2: Cpp.std.string = Cpp.cli.get_positional(1);
  let output: Cpp.std.string = Cpp.cli.get_positional(2);
  let p1_err: i32 = Validate.ValidatePath(input1);
  let p2_err: i32 = Validate.ValidatePath(input2);
  if (p1_err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (p1_err == 2) {
    Core.PrintStr(Cpp.color.red("error: input file not found: "));
    Core.PrintStr(input1);
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  if (p2_err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (p2_err == 2) {
    Core.PrintStr(Cpp.color.red("error: input file not found: "));
    Core.PrintStr(input2);
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  let list_content: Cpp.std.string = Cpp.build_concat_list_2(input1, input2);
  let list_path: Cpp.std.string = Cpp.write_temp_file(list_content, ".txt");
  if (list_path == "") {
    Core.PrintStr(Cpp.color.red("error: failed to create concat list file"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  ArgsBuilder.Clear();
  ArgsBuilder.Add(Constants.FfmpegBin());
  ArgsBuilder.Add(Constants.FlagOverwrite());
  ArgsBuilder.Add(Constants.FlagFormat());
  ArgsBuilder.Add(Cpp.strh.make("concat"));
  ArgsBuilder.Add(Cpp.strh.make("-safe"));
  ArgsBuilder.Add(Cpp.strh.make("0"));
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), list_path);
  if (Cpp.cli.has_flag("--copy") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
  } else {
    let codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
    if (codec != "") {
      ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), codec);
    }
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.Exec(cmd);
  Cpp.remove_temp_file(list_path);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

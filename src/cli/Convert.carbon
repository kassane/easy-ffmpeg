package Convert library "cli/convert";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg convert <input> <output>\n");
  Core.PrintStr("  --codec <codec>  Video codec (h264, hevc, vp9, av1, copy)\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg convert video.mkv output.mp4\n");
  Core.PrintStr("  easy-ffmpeg convert video.avi output.mp4 --codec copy\n");
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
  let codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (codec != "") {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), codec);
  } else {
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let codecs: Cpp.std.string = Cpp.probe_codecs(ffprobe, input);
    let sep: u64 = codecs.find(",");
    if (sep != 18446744073709551615) {
      let vcodec: Cpp.std.string = codecs.substr(0, sep);
      let acodec: Cpp.std.string = codecs.substr(sep + 1);
      let v_codec_h: Cpp.std.string = Cpp.strh.make(Constants.CodecNameH264());
      let aac: Cpp.std.string = Cpp.strh.make(Constants.CodecNameAac());
      if (vcodec == v_codec_h) {
        if (acodec == aac) {
          ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
          ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
        }
      }
    }
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

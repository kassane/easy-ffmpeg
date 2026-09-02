// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

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
  var codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");

  if (Cpp.str_ne(codec, "")) {
    // User specified codec — map aliases
    if (Cpp.str_eq(codec, Cpp.strh.make("h265"))) { codec = Cpp.strh.make(Constants.CodecHevc()); }
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), codec);
  } else {
    // Smart remux: probe codecs, check container compatibility
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let vcodec: Cpp.std.string = Cpp.probe_stream_codec(ffprobe, input, "v:0");
    let acodec: Cpp.std.string = Cpp.probe_stream_codec(ffprobe, input, "a:0");
    let fmt: Cpp.std.string = Cpp.format_for_ext(output);
    let v_ok: i32 = Cpp.video_compatible(vcodec, fmt);
    let a_ok: i32 = Cpp.audio_compatible(acodec, fmt);
    if (v_ok == 1 and a_ok == 1) {
      // All streams compatible — copy (zero quality loss, instant)
      ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
      ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
    } else if (v_ok == 1) {
      // Video compatible, audio needs re-encode
      ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.FlagCodecCopy());
    } else if (a_ok == 1) {
      // Audio compatible, video needs re-encode
      ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.FlagCodecCopy());
    }
    // Both incompatible — let ffmpeg use defaults (re-encode everything)
  }

  // Add normalization filters for h264/h265 output
  var enc: Cpp.std.string = Cpp.strh.make(Constants.DefaultVideoEncoder());
  if (Cpp.str_ne(codec, "")) { enc = codec; }
  if (Cpp.str_ne(enc, Constants.FlagCodecCopy())) {
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let pix: Cpp.std.string = Cpp.probe_pix_fmt(ffprobe, input);
    let w: i32 = Cpp.probe_width(ffprobe, input);
    let h: i32 = Cpp.probe_height(ffprobe, input);
    let vf: Cpp.std.string = Cpp.normalize_video_filters(pix, w, h, enc);
    if (Cpp.str_ne(vf, "")) {
      ArgsBuilder.AddFlagValue(Constants.FlagFilter(), vf);
    }
  }

  if (Cpp.cli.has_flag("--no-subs") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagSn(), Cpp.strh.make(""));
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  return Process.ExecAndReport(cmd, input);
}

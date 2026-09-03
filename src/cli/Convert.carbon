// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Convert library "cli/convert";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

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
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  var codec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");

  if (Cpp.str_ne(codec, "")) {
    // User specified codec — map aliases
    if (Cpp.str_eq(codec, Cpp.strh.make("h265"))) { codec = Cpp.strh.make(Constants.CodecHevc()); }
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), codec);
  } else {
    // Smart remux: probe codecs, check container compatibility
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let vcodec: Cpp.std.string = Cpp.probe_stream_codec(ffprobe, ctx.input, "v:0");
    let acodec: Cpp.std.string = Cpp.probe_stream_codec(ffprobe, ctx.input, "a:0");
    let fmt: Cpp.std.string = Cpp.format_for_ext(ctx.output);
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
    let pix: Cpp.std.string = Cpp.probe_pix_fmt(ffprobe, ctx.input);
    let w: i32 = Cpp.probe_width(ffprobe, ctx.input);
    let h: i32 = Cpp.probe_height(ffprobe, ctx.input);
    let vf: Cpp.std.string = Cpp.normalize_video_filters(pix, w, h, enc);
    if (Cpp.str_ne(vf, "")) {
      ArgsBuilder.AddFlagValue(Constants.FlagFilter(), vf);
    }
  }

  if (Cpp.cli.has_flag("--no-subs") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagSn(), Cpp.strh.make(""));
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

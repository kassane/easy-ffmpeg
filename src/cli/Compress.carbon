// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Compress library "cli/compress";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg compress <input> [output]\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Presets:\n"));
  Core.PrintStr("  --web         H.264+AAC, faststart, stereo\n");
  Core.PrintStr("  --mobile      H.264 720p, low bitrate\n");
  Core.PrintStr("  --streaming   H.265 CRF18, high quality\n");
  Core.PrintStr("  --compress    H.265 CRF28, small file (default)\n");
  Core.PrintStr("  --av1         AV1 CRF30, modern codec\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Fine-tune:\n"));
  Core.PrintStr("  --crf <n>        Quality (0-51, lower=better)\n");
  Core.PrintStr("  --preset <name>  Speed (ultrafast, fast, medium, slow)\n");
  Core.PrintStr("  --codec <codec>  Override video codec\n");
  Core.PrintStr("  --bitrate <br>   Audio bitrate\n");
  Core.PrintStr("  --audio-codec <c>  Audio codec override\n");
  Core.PrintStr("  --video-bitrate <br>  Video bitrate\n");
  Core.PrintStr("  --dry-run        Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg compress video.mp4 --web\n");
  Core.PrintStr("  easy-ffmpeg compress video.mp4 --av1\n");
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
  // Codec selection: custom or preset
  let vcodec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (Cpp.str_ne(vcodec, "")) {
    // Custom codec: respect --crf and --preset overrides
    let crf: Cpp.std.string = Cpp.cli.get_flag_value("--crf");
    let pset: Cpp.std.string = Cpp.cli.get_flag_value("--preset");
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), vcodec);
    if (Cpp.str_ne(crf, "")) { ArgsBuilder.AddFlagValue(Constants.FlagCrf(), crf); }
    if (Cpp.str_ne(pset, "")) { ArgsBuilder.AddFlagValue(Constants.FlagPreset(), pset); }
  } else {
    // Preset: build all args from C++ helper
    let fmt: Cpp.std.string = Cpp.format_for_ext(ctx.output);
    var pname: Cpp.std.string = Cpp.strh.make(Constants.PresetCompress());
    if (Cpp.cli.has_flag("--web") == 1) { pname = Cpp.strh.make(Constants.PresetWeb()); }
    else if (Cpp.cli.has_flag("--mobile") == 1) { pname = Cpp.strh.make(Constants.PresetMobile()); }
    else if (Cpp.cli.has_flag("--streaming") == 1) { pname = Cpp.strh.make(Constants.PresetStreaming()); }
    else if (Cpp.cli.has_flag("--av1") == 1) { pname = Cpp.strh.make(Constants.PresetAv1()); }
    else if (Cpp.cli.has_flag("--jxl") == 1) { pname = Cpp.strh.make(Constants.PresetJxl()); }
    let preset_args: Cpp.std.string = Cpp.build_compress_args(pname, fmt);
    // Tokenize and add each arg
    let toks: Cpp.std.string = preset_args;
    // Simple space-separated add
    var pos: u64 = 0;
    while (pos < toks.size()) {
      let space: u64 = toks.find(" ", pos);
      if (space == Constants.NotFoundIndex()) {
        ArgsBuilder.Add(toks.substr(pos));
        break;
      }
      let tok: Cpp.std.string = toks.substr(pos, space - pos);
      ArgsBuilder.Add(tok);
      pos = space + 1;
    }
  }
  // Add normalization filters for h264/h265
  let enc: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  if (Cpp.str_ne(enc, "")) {
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let pix: Cpp.std.string = Cpp.probe_pix_fmt(ffprobe, ctx.input);
    let w: i32 = Cpp.probe_width(ffprobe, ctx.input);
    let h: i32 = Cpp.probe_height(ffprobe, ctx.input);
    let vf: Cpp.std.string = Cpp.normalize_video_filters(pix, w, h, enc);
    if (Cpp.str_ne(vf, "")) { ArgsBuilder.AddFlagValue(Constants.FlagFilter(), vf); }
  }
  // Audio downmix to stereo for web/mobile
  if (Cpp.cli.has_flag("--web") == 1 or Cpp.cli.has_flag("--mobile") == 1) {
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let ch: i32 = Cpp.probe_channels(ffprobe, ctx.input);
    if (ch > 2) { ArgsBuilder.AddFlagValue(Constants.FlagAc(), Constants.StereoChannels()); }
  }
  // Audio codec: override preset default (presets already set -c:a)
  let acodec: Cpp.std.string = Cpp.cli.get_flag_value("--audio-codec");
  if (Cpp.str_ne(acodec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), acodec);
  }
  // Audio bitrate: override preset default
  let abr: Cpp.std.string = Cpp.cli.get_flag_value("--bitrate");
  if (Cpp.str_ne(abr, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), abr);
  }
  let vbr: Cpp.std.string = Cpp.cli.get_flag_value("--video-bitrate");
  if (Cpp.str_ne(vbr, "")) {
    ArgsBuilder.AddFlagValue(Cpp.strh.make(Constants.FlagVideoBitrate()), vbr);
  }
  // Mobile scale: preset already includes this, only add for custom codec
  if (Cpp.cli.has_flag("--mobile") == 1 and Cpp.str_ne(vcodec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Constants.ScaleFilterHd());
  }
  if (Cpp.str_eq(ctx.output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  // Strip subtitles for web/mobile presets or explicit --no-subs
  if (Cpp.cli.has_flag("--no-subs") == 1 or Cpp.cli.has_flag("--web") == 1 or Cpp.cli.has_flag("--mobile") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagSn(), Cpp.strh.make(""));
  }
  ArgsBuilder.Add(ctx.output);
  return ctx.Exec();
}

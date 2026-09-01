// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

package Compress library "cli/compress";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

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
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
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
    let fmt: Cpp.std.string = Cpp.format_for_ext(output);
    var pname: Cpp.std.string = Cpp.strh.make("compress");
    if (Cpp.cli.has_flag("--web") == 1) { pname = Cpp.strh.make("web"); }
    else if (Cpp.cli.has_flag("--mobile") == 1) { pname = Cpp.strh.make("mobile"); }
    else if (Cpp.cli.has_flag("--streaming") == 1) { pname = Cpp.strh.make("streaming"); }
    else if (Cpp.cli.has_flag("--av1") == 1) { pname = Cpp.strh.make("av1"); }
    else if (Cpp.cli.has_flag("--jxl") == 1) { pname = Cpp.strh.make("jxl"); }
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
    let pix: Cpp.std.string = Cpp.probe_pix_fmt(ffprobe, input);
    let w: i32 = Cpp.probe_width(ffprobe, input);
    let h: i32 = Cpp.probe_height(ffprobe, input);
    let vf: Cpp.std.string = Cpp.normalize_video_filters(pix, w, h, enc);
    if (Cpp.str_ne(vf, "")) { ArgsBuilder.AddFlagValue(Constants.FlagFilter(), vf); }
  }
  // Audio downmix to stereo for web/mobile
  if (Cpp.cli.has_flag("--web") == 1 or Cpp.cli.has_flag("--mobile") == 1) {
    let ffprobe: Cpp.std.string = Cpp.strh.make(Constants.FfprobeBin());
    let ch: i32 = Cpp.probe_channels(ffprobe, input);
    if (ch > 2) { ArgsBuilder.AddFlagValue(Cpp.strh.make("-ac"), Cpp.strh.make("2")); }
  }
  let acodec: Cpp.std.string = Cpp.cli.get_flag_value("--audio-codec");
  if (Cpp.str_ne(acodec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), acodec);
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.CodecAac());
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
  if (Cpp.cli.has_flag("--web") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagMovflags(), Constants.FaststartValue());
  }
  if (Cpp.cli.has_flag("--mobile") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), Constants.ScaleFilterHd());
  }
  if (Cpp.str_eq(output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  // Strip subtitles for web/mobile presets or explicit --no-subs
  if (Cpp.cli.has_flag("--no-subs") == 1 or Cpp.cli.has_flag("--web") == 1 or Cpp.cli.has_flag("--mobile") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagSn(), Cpp.strh.make(""));
  }
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

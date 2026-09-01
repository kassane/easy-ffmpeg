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
  let vcodec: Cpp.std.string = Cpp.cli.get_flag_value("--codec");
  let crf: Cpp.std.string = Cpp.cli.get_flag_value("--crf");
  let preset: Cpp.std.string = Cpp.cli.get_flag_value("--preset");
  let abr: Cpp.std.string = Cpp.cli.get_flag_value("--bitrate");
  if (Cpp.str_ne(vcodec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), vcodec);
    if (Cpp.str_ne(crf, "")) { ArgsBuilder.AddFlagValue(Constants.FlagCrf(), crf); }
    if (Cpp.str_ne(preset, "")) { ArgsBuilder.AddFlagValue(Constants.FlagPreset(), preset); }
  } else if (Cpp.cli.has_flag("--web") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecLibx264());
    ArgsBuilder.AddFlagValue(Constants.FlagCrf(), Constants.PresetWebCrf());
    ArgsBuilder.AddFlagValue(Constants.FlagPreset(), Constants.PresetWebPreset());
  } else if (Cpp.cli.has_flag("--mobile") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecLibx264());
    ArgsBuilder.AddFlagValue(Constants.FlagCrf(), Constants.PresetMobileCrf());
    ArgsBuilder.AddFlagValue(Constants.FlagPreset(), Constants.PresetMobilePreset());
  } else if (Cpp.cli.has_flag("--streaming") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecLibx265());
    ArgsBuilder.AddFlagValue(Constants.FlagCrf(), Constants.PresetStreamingCrf());
    ArgsBuilder.AddFlagValue(Constants.FlagPreset(), Constants.PresetStreamingPreset());
  } else if (Cpp.cli.has_flag("--av1") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecLibsvtav1());
    ArgsBuilder.AddFlagValue(Constants.FlagCrf(), Constants.PresetAv1Crf());
    ArgsBuilder.AddFlagValue(Constants.FlagPreset(), Constants.PresetAv1Preset());
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagOutputCodec(), Constants.CodecLibx265());
    ArgsBuilder.AddFlagValue(Constants.FlagCrf(), Constants.PresetCompressCrf());
    ArgsBuilder.AddFlagValue(Constants.FlagPreset(), Constants.PresetCompressPreset());
  }
  let acodec: Cpp.std.string = Cpp.cli.get_flag_value("--audio-codec");
  if (Cpp.str_ne(acodec, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), acodec);
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioCodec(), Constants.CodecAac());
  }
  if (Cpp.str_ne(abr, "")) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), abr);
  } else if (Cpp.cli.has_flag("--mobile") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), Constants.PresetMobileAudioBr());
  } else if (Cpp.cli.has_flag("--streaming") == 1) {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), Constants.PresetStreamingAudioBr());
  } else {
    ArgsBuilder.AddFlagValue(Constants.FlagAudioBr(), Constants.PresetCompressAudioBr());
  }
  let vbr: Cpp.std.string = Cpp.cli.get_flag_value("--video-bitrate");
  if (Cpp.str_ne(vbr, "")) {
    ArgsBuilder.AddFlagValue(Cpp.strh.make(Constants.FlagVideoBitrate()), vbr);
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
  ArgsBuilder.Add(output);
  let cmd: Cpp.std.string = ArgsBuilder.ToSystemCmd();
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let rc: i32 = Process.ExecProgress(cmd, Cpp.strh.make(Constants.FfprobeBin()), input);
  Core.PrintStr("exit code="); Core.Print(rc); Core.PrintStr("\n");
  return rc;
}

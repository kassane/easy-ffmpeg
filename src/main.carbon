import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";
import Convert library "cli/convert";
import Compress library "cli/compress";
import Trim library "cli/trim";
import Resize library "cli/resize";
import AudioExtract library "cli/audioextract";
import Probe library "cli/probe";
import Constants library "core/constants";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("easy-ffmpeg"));
  Core.PrintStr(" — friendly ffmpeg wrapper\n");
  Core.PrintStr("Usage: easy-ffmpeg <command> [options]\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Commands:\n"));
  Core.PrintStr("  convert       Convert between formats (smart remux)\n");
  Core.PrintStr("  compress      Compress video with presets\n");
  Core.PrintStr("  trim          Cut a segment from a media file\n");
  Core.PrintStr("  resize        Scale video dimensions\n");
  Core.PrintStr("  audio-extract Extract audio track from video\n");
  Core.PrintStr("  probe         Show media file information\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Presets (use with compress):\n"));
  Core.PrintStr("  --web         H.264+AAC, faststart, stereo\n");
  Core.PrintStr("  --mobile      H.264 720p, low bitrate\n");
  Core.PrintStr("  --streaming   H.265 CRF18, high quality\n");
  Core.PrintStr("  --compress    H.265 CRF28, small file\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Scale presets (use with resize):\n"));
  Core.PrintStr("  --scale hd       720p\n");
  Core.PrintStr("  --scale fullhd   1080p\n");
  Core.PrintStr("  --scale 2k       1440p\n");
  Core.PrintStr("  --scale retro    480p\n");
  Core.PrintStr("  --scale icon     240p\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --dry-run     Print ffmpeg command without executing\n");
  Core.PrintStr("  -v, --version Show version\n");
  Core.PrintStr("  -h, --help    Show this help message\n");
}

fn Run() {
  Cpp.cli.capture();

  if (Cpp.cli.argc() < 2) {
    ShowHelp();
    Cpp.cli_exit(Constants.ExitUsage());
    return;
  }

  if (Cpp.cli.arg_matches(1, "--help") == 1) {
    ShowHelp();
    Cpp.cli_exit(Constants.ExitSuccess());
    return;
  }
  if (Cpp.cli.arg_matches(1, "-h") == 1) {
    ShowHelp();
    Cpp.cli_exit(Constants.ExitSuccess());
    return;
  }

  if (Cpp.cli.arg_matches(1, "--version") == 1) {
    Core.PrintStr("easy-ffmpeg ");
    Core.PrintStr(Constants.Version());
    Core.PrintStr("\n");
    Cpp.cli_exit(Constants.ExitSuccess());
    return;
  }
  if (Cpp.cli.arg_matches(1, "-v") == 1) {
    Core.PrintStr("easy-ffmpeg ");
    Core.PrintStr(Constants.Version());
    Core.PrintStr("\n");
    Cpp.cli_exit(Constants.ExitSuccess());
    return;
  }

  if (Cpp.cli.arg_matches(1, "convert") == 1) {
    let rc: i32 = Convert.Run();
    Cpp.cli_exit(rc);
    return;
  }
  if (Cpp.cli.arg_matches(1, "compress") == 1) {
    let rc: i32 = Compress.Run();
    Cpp.cli_exit(rc);
    return;
  }
  if (Cpp.cli.arg_matches(1, "trim") == 1) {
    let rc: i32 = Trim.Run();
    Cpp.cli_exit(rc);
    return;
  }
  if (Cpp.cli.arg_matches(1, "resize") == 1) {
    let rc: i32 = Resize.Run();
    Cpp.cli_exit(rc);
    return;
  }
  if (Cpp.cli.arg_matches(1, "audio-extract") == 1) {
    let rc: i32 = AudioExtract.Run();
    Cpp.cli_exit(rc);
    return;
  }
  if (Cpp.cli.arg_matches(1, "probe") == 1) {
    let rc: i32 = Probe.Run();
    Cpp.cli_exit(rc);
    return;
  }

  Core.PrintStr(Cpp.color.red("error: unknown command"));
  Core.PrintStr("\n");
  Cpp.cli_exit(Constants.ExitUsage());
}

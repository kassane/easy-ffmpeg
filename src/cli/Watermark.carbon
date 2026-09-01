package Watermark library "cli/watermark";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg watermark <input> <output>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Options:\n"));
  Core.PrintStr("  --image <file>           Watermark image file\n");
  Core.PrintStr("  --text <text>            Text watermark\n");
  Core.PrintStr("  --position <pos>         Position: top-left, top-right, bottom-left, bottom-right, center\n");
  Core.PrintStr("  --dry-run                Print ffmpeg command without executing\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Examples:\n"));
  Core.PrintStr("  easy-ffmpeg watermark video.mp4 out.mp4 --image logo.png\n");
  Core.PrintStr("  easy-ffmpeg watermark video.mp4 out.mp4 --text \"Sample\" --position center\n");
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
  if (Cpp.str_eq(output, "")) {
    Core.PrintStr(Cpp.color.red("error: output file required"));
    Core.PrintStr("\n");
    return Constants.ExitFailure();
  }
  let image: Cpp.std.string = Cpp.cli.get_flag_value("--image");
  let text: Cpp.std.string = Cpp.cli.get_flag_value("--text");
  let position: Cpp.std.string = Cpp.cli.get_flag_value("--position");
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), input);
  if (Cpp.str_ne(image, "")) {
    let img_err: i32 = Validate.ValidatePath(image);
    if (img_err == 1) {
      Core.PrintStr(Cpp.color.red("error: image path traversal not allowed"));
      Core.PrintStr("\n");
      return Constants.ExitSecurity();
    }
    if (img_err == 2) {
      Core.PrintStr(Cpp.color.red("error: image file not found: "));
      Core.PrintStr(image);
      Core.PrintStr("\n");
      return Constants.ExitFileNotFound();
    }
    ArgsBuilder.AddFlagValue(Constants.FlagInput(), image);
    let overlay: Cpp.std.string = Cpp.build_watermark_filter(position);
    let filter_complex: Cpp.std.string = Cpp.strh.concat3("[0:v][1:v]", overlay, "[out]");
    ArgsBuilder.AddFlagValue(Constants.FlagFilterComplex(), filter_complex);
    ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("[out]"));
    ArgsBuilder.AddFlagValue(Constants.FlagMap(), Cpp.strh.make("0:a?"));
  } else if (Cpp.str_ne(text, "")) {
    let safe_text: Cpp.std.string = Cpp.escape_drawtext(text);
    let filter: Cpp.std.string = Cpp.strh.concat3("drawtext=text=", safe_text, ":fontsize=24:fontcolor=white:x=10:y=10");
    ArgsBuilder.AddFlagValue(Constants.FlagFilter(), filter);
  } else {
    Core.PrintStr(Cpp.color.red("error: --image or --text required"));
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

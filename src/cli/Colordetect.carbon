// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca
package Colordetect library "cli/colordetect";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Validate library "core/validate";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg colordetect <input>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Description:\n"));
  Core.PrintStr("  Detects video color properties (range, alpha mode).\n");
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
  let cmd: Cpp.std.string = Cpp.strh.concat3(
    "ffmpeg -i ", input, " -vf colordetect -f null -");
  if (Cpp.cli.is_dry_run() == 1) { Cpp.print_str(cmd); return Constants.ExitSuccess(); }
  let out: Cpp.std.string = Cpp.process.run_capture_stderr(cmd);
  Core.PrintStr(Cpp.color.bold("Color properties:\n"));
  let rs: u64 = out.find("Color range:");
  if (rs != Constants.NotFoundIndex()) {
    var re: u64 = out.find("\n", rs);
    if (re == Constants.NotFoundIndex()) { re = out.size(); }
    Core.PrintStr("  "); Core.PrintStr(out.substr(rs, re - rs)); Core.PrintStr("\n");
  }
  let aa: u64 = out.find("Alpha mode:");
  if (aa != Constants.NotFoundIndex()) {
    var ae: u64 = out.find("\n", aa);
    if (ae == Constants.NotFoundIndex()) { ae = out.size(); }
    Core.PrintStr("  "); Core.PrintStr(out.substr(aa, ae - aa)); Core.PrintStr("\n");
  }
  return Constants.ExitSuccess();
}

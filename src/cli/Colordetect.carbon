// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca
package Colordetect library "cli/colordetect";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Ctx library "core/command_context";
import Cpp library "ffi_helper.hpp";

fn ShowHelp() {
  Core.PrintStr(Cpp.color.bold("Usage:"));
  Core.PrintStr(" easy-ffmpeg colordetect <input>\n");
  Core.PrintStr("\n");
  Core.PrintStr(Cpp.color.bold("Description:\n"));
  Core.PrintStr("  Detects video color properties (range, alpha mode).\n");
}

fn Run() -> i32 {
  if (Cpp.cli.has_help() == 1) { ShowHelp(); return Constants.ExitSuccess(); }
  var ctx: Ctx.CommandContext = Ctx.CommandContext.Make();
  let rc: i32 = ctx.LoadInput(1);
  if (rc != 0) { return rc; }
  ArgsBuilder.StartFfmpeg();
  ArgsBuilder.AddFlagValue(Constants.FlagInput(), ctx.input);
  ArgsBuilder.Add(Cpp.strh.make("-vf"));
  ArgsBuilder.Add(Cpp.strh.make("colordetect"));
  ArgsBuilder.Add(Cpp.strh.make("-f"));
  ArgsBuilder.Add(Cpp.strh.make("null"));
  ArgsBuilder.Add(Cpp.strh.make("-"));
  if (Cpp.cli.is_dry_run() == 1) {
    Cpp.print_str(ArgsBuilder.ToSystemCmd());
    return Constants.ExitSuccess();
  }
  let out: Cpp.std.string = Cpp.process.run_capture_stderr(ArgsBuilder.ToSystemCmd());
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

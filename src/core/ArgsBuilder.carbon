// Accumulates argv tokens into a command string via C++ static buffer.
// Carbon can't hold mutable state, so accumulation lives in ffi_helper.hpp.
package ArgsBuilder library "core/args";
import Constants library "core/constants";
import Cpp library "ffi_helper.hpp";

fn Clear() {
  Cpp.argv_clear();
}

fn Add(s: Core.String) -> Cpp.std.string {
  return Cpp.argv_add_token(s);
}

fn AddFlagValue(flag: Core.String, value: Core.String) {
  Cpp.argv_add_token(flag);
  Cpp.argv_add_token(value);
}

fn AddMany(a: Core.String, b: Core.String) {
  Cpp.argv_add_token(a);
  Cpp.argv_add_token(b);
}

fn AddMany3(a: Core.String, b: Core.String, c: Core.String) {
  Cpp.argv_add_token(a);
  Cpp.argv_add_token(b);
  Cpp.argv_add_token(c);
}

fn AddMany4(a: Core.String, b: Core.String, c: Core.String, d: Core.String) {
  Cpp.argv_add_token(a);
  Cpp.argv_add_token(b);
  Cpp.argv_add_token(c);
  Cpp.argv_add_token(d);
}

fn AddMany5(a: Core.String, b: Core.String, c: Core.String, d: Core.String, e: Core.String) {
  Cpp.argv_add_token(a);
  Cpp.argv_add_token(b);
  Cpp.argv_add_token(c);
  Cpp.argv_add_token(d);
  Cpp.argv_add_token(e);
}

// Common setup: Clear + FfmpegBin + FlagOverwrite. Used by every CLI command.
fn StartFfmpeg() {
  Clear();
  Add(Constants.FfmpegBin());
  Add(Constants.FlagOverwrite());
}

// Common build command setup: Clear + carbon build src/main + core + cli + flags.
fn StartBuild(tc: Cpp.std.string) {
  Clear();
  Add(tc);
  Add(Cpp.strh.make("build"));
  Add(Cpp.strh.make("src/main.carbon"));
  Add(Cpp.strh.make("src/core/*.carbon"));
  Add(Cpp.strh.make("src/cli/*.carbon"));
  Add(Cpp.strh.make("--output=easy-ffmpeg"));
  Add(Cpp.strh.make("--"));
  Add(Cpp.strh.make("-std=c++23"));
  Add(Cpp.strh.make("-Isrc/core"));
  Add(Cpp.strh.make("-Wall"));
  Add(Cpp.strh.make("-Wextra"));
  Add(Cpp.strh.make("-fstack-protector-strong"));
  Add(Cpp.strh.make("-D_FORTIFY_SOURCE=2"));
}

fn ToSystemCmd() -> Cpp.std.string {
  return Cpp.argv_build_cmd();
}

fn RunShell() -> i32 {
  return Cpp.argv_run_shell();
}

fn RunExec() -> i32 {
  return Cpp.argv_run_exec();
}

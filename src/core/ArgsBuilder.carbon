// Accumulates argv tokens into a command string via C++ static buffer.
// Carbon can't hold mutable state, so accumulation lives in ffi_helper.hpp.
package ArgsBuilder library "core/args";
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

fn ToSystemCmd() -> Cpp.std.string {
  return Cpp.argv_build_cmd();
}

fn RunShell() -> i32 {
  return Cpp.argv_run_shell();
}

fn RunExec() -> i32 {
  return Cpp.argv_run_exec();
}

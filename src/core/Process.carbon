// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

// Single exec path. All process execution goes through Exec().
// Bridges Carbon strings to C system() via std::string in ffi_helper.hpp.
package Process library "core/process";
import Cpp library "ffi_helper.hpp";

// Runs a shell command. Returns exit code, or -1 on fork failure.
// Input must be validated by Validate.carbon first.
fn Exec(cmd: Cpp.std.string) -> i32 {
  return Cpp.process.run_str(cmd);
}

// Runs command with progress bar. Needs ffprobe path + input for duration.
fn ExecProgress(cmd: Cpp.std.string, ffprobe: Cpp.std.string, input: Cpp.std.string) -> i32 {
  let total_ms: i64 = Cpp.probe_duration_ms(ffprobe, input);
  return Cpp.run_progress(cmd, total_ms);
}

// Runs a command and captures stdout.
fn RunCapture(cmd: Cpp.std.string) -> Cpp.std.string {
  return Cpp.process.run_capture(cmd);
}

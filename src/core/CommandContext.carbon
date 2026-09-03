// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

// CLI command lifecycle: load positionals, validate, execute.
package Ctx library "core/command_context";
import ArgsBuilder library "core/args";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";
import Process library "core/process";
import Validate library "core/validate";

// Holds input/output paths and execution state.
class CommandContext {
  var input: Cpp.std.string;
  var output: Cpp.std.string;

  fn Make() -> Self {
    return {
      .input = Cpp.strh.make(""),
      .output = Cpp.strh.make("")
    };
  }

  // Load input positional and validate.
  fn LoadInput(ref self, min_args: i32) -> i32 {
    if (Cpp.cli.positional_count() < min_args) {
      Core.PrintStr(Cpp.color.red("error: need input file"));
      Core.PrintStr("\n");
      return Constants.ExitFailure();
    }
    self.input = Cpp.cli.get_positional(0);
    return Validate.CheckInput(self.input);
  }

  // Load input + output positionals with validation.
  fn LoadInputOutput(ref self) -> i32 {
    let rc: i32 = self.LoadInput(2);
    if (rc != 0) { return rc; }
    self.output = Cpp.cli.get_positional(1);
    // Validate output path (traversal only — existence is checked later).
    let out_err: i32 = Validate.ValidatePath(self.output);
    if (out_err == 1) {
      Core.PrintStr(Cpp.color.red("error: output path traversal not allowed"));
      Core.PrintStr("\n");
      return Constants.ExitSecurity();
    }
    return Constants.ExitSuccess();
  }

  // Check output exists. Returns nonzero=exit code if output exists without --force.
  fn CheckOutput(self) -> i32 {
    if (Cpp.str_eq(self.output, "")) { return Constants.ExitSuccess(); }
    if (Validate.Exists(self.output)) {
      if (Cpp.cli.has_flag(Constants.FlagForce()) == 0) {
        Core.PrintStr(Cpp.color.red("error: output file already exists: "));
        Cpp.print_str(self.output);
        Core.PrintStr("\n");
        Core.PrintStr("  Use --force to overwrite.\n");
        return Constants.ExitFailure();
      }
    }
    return Constants.ExitSuccess();
  }

  // Print command if dry-run. Returns true if dry-run (caller should return).
  fn DryRun() -> bool {
    if (Cpp.cli.is_dry_run() == 1) {
      Cpp.print_str(ArgsBuilder.ToSystemCmd());
      return true;
    }
    return false;
  }

  // Execute with progress bar.
  fn Exec(self) -> i32 {
    if (DryRun()) { return Constants.ExitSuccess(); }
    return Process.ExecAndReport(ArgsBuilder.ToSystemCmd(), self.input);
  }

  // Execute simple (no progress bar). Static.
  fn ExecSimple() -> i32 {
    if (Cpp.cli.is_dry_run() == 1) {
      Cpp.print_str(ArgsBuilder.ToSystemCmd());
      return Constants.ExitSuccess();
    }
    return Process.ExecSimple(ArgsBuilder.ToSystemCmd());
  }
}

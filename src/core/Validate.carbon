// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Matheus C. Franca

// Input validation before any process execution.
// String parsing/comparison happens in C++ (Carbon lacks string == and slicing).
package Validate library "core/validate";
import Constants library "core/constants";
import Core library "io";
import Cpp library "ffi_helper.hpp";

fn Exists(path: Core.String) -> bool {
  return Cpp.process.exists(path);
}

// Validate path: 0=ok, 1=..traversal, 2=not regular file.
fn ValidatePath(path: Core.String) -> i32 {
  return Cpp.process.validate_path(path);
}

// Validate input path and print error. Returns 0=ok, nonzero=exit code.
fn CheckInput(input: Core.String) -> i32 {
  let err: i32 = ValidatePath(input);
  if (err == 1) {
    Core.PrintStr(Cpp.color.red("error: path traversal not allowed"));
    Core.PrintStr("\n");
    return Constants.ExitSecurity();
  }
  if (err == 2) {
    Core.PrintStr(Cpp.color.red("error: input file not found or not a regular file"));
    Core.PrintStr("\n");
    return Constants.ExitFileNotFound();
  }
  return Constants.ExitSuccess();
}
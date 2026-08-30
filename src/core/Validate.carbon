// Input validation before any process execution.
// String parsing/comparison happens in C++ (Carbon lacks string == and slicing).
package Validate library "core/validate";
import Core library "io";
import Core library "prelude/types";
import Cpp library "ffi_helper.hpp";

fn Exists(path: Core.String) -> bool {
  return Cpp.process.exists(path);
}

// Validate path: 0=ok, 1=..traversal, 2=not regular file.
fn ValidatePath(path: Core.String) -> i32 {
  return Cpp.process.validate_path(path);
}
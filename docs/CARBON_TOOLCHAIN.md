# Carbon Toolchain Notes (2026-08-29 nightly)

> Verbatim ground truth from `carbon --help`, `carbon build --help`, `carbon compile --help`, `carbon link --help`, and `$CARBON config`. This is the executable source of build truth; docs must not drift from it.

## Version

```
Carbon Language toolchain version: 0.0.0-0.nightly.2026.08.29+f519ccc
Install root: $PWD/carbon_toolchain-0.0.0-0.nightly.2026.08.29/lib/carbon/
Default target: x86_64-unknown-linux-gnu
```

Resolve always via `scripts/env.sh`:
```sh
export CARBON="$PWD"/carbon_toolchain-0.0.0-0.nightly.2026.08.29/bin/carbon
```

## Build / Compile / Link

| Task | Command |
|------|---------|
| Compile to object | `$CARBON compile --output=x.o src/file.carbon` |
| **Compile + link executable** | `$CARBON build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=easy-ffmpeg` |
| Link precompiled objects | `$CARBON link --output=easy-ffmpeg a.o b.o` |
| Pass extra clang/include/link args | `$CARBON build file.carbon -- -I/usr/include -lavcodec -lavformat` (after the first `--`) |
| Format | `$CARBON format src/**/*.carbon` |
| Phase gate (check only) | `$CARBON compile --phase=check file.carbon` |
| Optimize | `$CARBON build file.carbon --optimize=(none|debug|speed|size)` |

**Ordering quirk (verified):** the `-o`/`--output` flag on `build` must be given a value — bare `-o` errors with `option -o requires a value`. Always write `--output=NAME`.

## Import model

- Standard/stdlib via `import Core library "io";` — `Core.Print(i32)`, `Core.PrintStr(str)`, `Core.ReadChar`.
- **C++ interop:** `import Cpp library "<cstdio>";` then call `Cpp.putchar`, `Cpp.system`, etc. The `Cpp.` prefix is mandatory; Carbon maps types with explicit `as` casts (e.g. `n as u8 as i32`).
- Prelude ships only: `copy/default/destroy/iterate/range/operators/types bool,char,char_literal,float,float_literal,form,int,int_literal,maybe_unformed,optional,string,uint,cpp(int,nullptr,void)` — **no `Vector`, no `String.format`, no heap allocator, no argparse.** See `lib/carbon/core/prelude_manifest.txt`.
- Link runtimes build on demand; need `libgcc-11-dev` (see README).

## Constraints for easy-ffmpeg

- **No `Vector<String>`** → use `Array(String, MinArgs)` with a `len: i32`. Marked `// ponytail: fixed 64, heap Vector when prelude ships`.
- **No `match` sugar** → dispatch with `if (argv[1] == Constants.CmdConvert)`.
- **Exec via `Cpp.system`** — no `libav*` import until 0.2 (templates not safe). Keep interop to `<cstdlib>`/`<cstdio>`. Run commands through a `std::string` bridge (see below), not raw pointers.
- **Every literal lives in `Constants.carbon`** — `grep` gate enforces. Use **functions**, not `let` constants, in `Constants.carbon` (cross-package `let` refs crash the compiler — see below).
- **Custom headers** — `import Cpp library "ffi_helper.hpp"` compiles/links when the include dir is passed: `carbon build ... -- -std=c++17 -Isrc/core`.

## Precendents

- Reference doc: `docs/ARCHITECTURE.md` data-flow, `docs/RULES.md` constraints, `README.md` quickstart.

## Verified interop + entry-point gotchas (empirically tested 2026-08-29)

* **Entry function is `fn Run()`, NOT `fn Main() -> i32`.** Linking `fn Main() -> i32` produces `undefined symbol: main` because the runtime expects `_CMain.Run` (the prelude supplies the real C `main` that calls `Run`). Docs example `fn Run() { Core.Print(42); }` builds and runs cleanly.
* **`Cpp.char*` does not parse** — `char` is a Carbon reserved word; `as Cpp.char*` errors. Cast through what imports: `Cpp.putchar(c as i32)` with `let c: Core.Char = 'H';` works (Char adapts u8, converts to i32).
* **`'\n'.Code()` does not exist on `CharLiteral`** — use `10 as i32` for newline.
* **Verified working build+run:**
  ```carbon
  import Core library "io";
  import Cpp library "<cstdio>";
  fn Run() {
    let c: Core.Char = 'H';
    Cpp.putchar(c as i32);
    Cpp.putchar(10 as i32);
    Core.Print(42);
  }
  // carbon build full.carbon --output=full && ./full   => "H\n42"
  ```
* **`fn Run()` has no `-> i32`** — it returns nothing; return process code implicitly ok (docs demo runs rc=0).
* **`let` does NOT infer types.** `let x = 42;` fails with `name 'x' not found` (plus `expression pattern` semantics TODO). You **must** annotate explicitly: `let x: i32 = 42;`. This is a hard toolchain constraint on 2026.08.29 nightly — every `let` needs an explicit type. See `MEMORY.md` `carbon/let-type-inference-disabled`.
* **Custom headers compile/link** — `import Cpp library "ffi_helper.hpp"` works when the include dir is passed after `--`: `carbon build src/main.carbon src/core/*.carbon --output=/tmp/out -- -std=c++17 -Isrc/core`. Without `-Isrc/core`, the header isn't found.
* **Cpp.system via std::string bridge** — Carbon wraps POINTER returns (`void*`, `char*`) in `Optional` (inaccessible this nightly), but VALUE types like `Cpp.std.string` work. Recipe: `Cpp.strh.make(Core.String)` → `Cpp.std.string`, then `Cpp.system(cmd.c_str())`. Verified: runs ffmpeg. See `MEMORY.md` `cpp_system_approach.md`.
* **CRASH: cross-package `let` constant refs** — `let x: Core.String = Constants.FfmpegBin;` (referencing a package-level `let` from another package) triggers a CHECK failure in lowering: `const_id.is_concrete()`. Workaround: use **functions** in `Constants.carbon` (`fn FfmpegBin() -> Core.String`), which work cross-package. See `MEMORY.md` `cpp_compiler_crash.md`.
* **`!bool` not supported** — use `x == false` instead.
* **`x as i32`** cast works; `i32(x)` function-style cast does NOT.

# Rules — easy-ffmpeg

> Enforced at review, pre-commit, and CI. Derived from `/init` + skill refs.

## 1. Avoid Redundancies

* **Single source of truth** per concept. If you add a flag, codec, preset, error code, or help string — it goes in **one** file (`src/core/Constants.carbon`). No copy-paste into `cli/*.carbon`.
* **One builder, one exec, one validator.** `grep -R "Add(" src/cli` must call `ArgsBuilder` methods; direct `"-c:v"` literals outside `Constants.carbon` fail C++ build checks (`Cpp.build.check_no_magic`).
* **DRY grep gate (pre-commit):**
  ```sh
  # must be zero hits
  grep -rn '"-c:v"\|"-b:v"\|"-ss"\|"h264"\|"aac"' src --exclude=Constants.carbon && exit 1
  # No longer needed: C++ build check enforces this
  ```
* **Reuse existing helpers.** `Validate.Exists`, `Validate.ParseTime` — don't reimplement per command.
* **Docs DRY:** `README.md` links to `docs/*`; don't duplicate flag tables. `docs/FFMPEG_COVERAGE.md` is generated, not hand-edited.

## 2. Avoid Magic Numbers / Strings

* **All literals in `Constants.carbon`.** Examples:
  ```carbon
  fn FlagInput() -> Core.String { return "-i"; }
  fn FlagOutputCodec() -> Core.String { return "-c:v"; }
  fn FlagStart() -> Core.String { return "-ss"; }
  fn FlagDuration() -> Core.String { return "-t"; }
  let DefaultCrf: i32 = 23;
  let DefaultPreset: String = "medium";
  let MaxArgs: i32 = 64; // ponytail: fixed 64, grow when prelude ships Vector
  fn ExitSuccess() -> i32 { return 0; }
  fn ExitUsage() -> i32 { return 2; }
  fn ExitFileNotFound() -> i32 { return 3; }
  fn CodecH264() -> Core.String { return "h264"; }
  fn VideoCodecToString(c: VideoCodec) -> String { ... } // single mapping
  ```
* **No bare numbers in logic.** `if (crf > 51)` → `if (crf > Constants.MaxCrf)`
* **Time parsing:** `Validate.ParseTime` centralizes `00:01:30` / `30s` / `1500ms` → `MaxDurationMs`, `MinDurationMs` in constants.
* **CI check:** C++ build check (`Cpp.build.check_no_magic`) fails on `/\b\d{2,}\b/` outside `Constants.carbon:`, `/".*"/` outside allowed files.

## 3. Looping Toolcall

* **Applies to builds, not to writing docs.** Reference: `loop-engineering/SKILL.md` (Grill → successCommand).
* **Loop spec:**
  - Goal: `carbon build` + smoke (`--help`, `--dry-run`, `probe`) green.
  - Success type: `command` → `scripts/loop-build.sh --once --check`
  - Executor: `fixer` lane; verifier: `oracle`/`observer` lane.
  - Max attempts: 3, then escalate.
* **Implementation:** `scripts/loop-build.sh`
  ```sh
  CARBON=$PWD/carbon_toolchain-*/bin/carbon
  while true; do
    $CARBON build src/main.carbon src/core/*.carbon src/cli/*.carbon --output=/tmp/easy-ffmpeg \
      && /tmp/easy-ffmpeg --help | grep -q "convert" \
      && /tmp/easy-ffmpeg convert --dry-run fixtures/in.mp4 --to mp4 /tmp/out.mp4 \
      && echo "[green] $(date -u +%FT%TZ)" && break
    sleep 1
    inotifywait -q -e modify,close_write src/**/*.carbon 2>/dev/null || sleep 2
  done
  ```
* **Manual review gate:** `loop-engineering` `onManualReview` → human runs `scripts/loop-build.sh --once` and calls `resolveManualReview`.
## 4. Skill References Applied

| Skill | How it shapes this repo |
|-------|------------------------|
| `loop-engineering` | `scripts/loop-build.sh` Grill contract, Monitor callbacks. |

| `security-audit` | `docs/SECURITY.md` — fork+execvp (no shell), allow-list validation. |
| `simplify` / `codemap` | `ARCHITECTURE.md` single builder, `codemap.md` per folder after init. |

## Enforcement Checklist (PR must pass)

- [ ] `carbon format src/**/*.carbon` clean
- [ ] `./build --check` clean (C++ native)
- [ ] `./build --ci` passes
- [ ] `./build --once` green (evidence attached in PR description)

## 5. Build via build.carbon Only

* **Never run `carbon build` directly.** Always use `./build --output=easy-ffmpeg`.
* `build.carbon` applies `-std=c++23`, `-Isrc/core`, link flags, and the ArgsBuilder dependency chain. Direct `carbon build` skips all of that.
* CI gate: `./build --output=easy-ffmpeg` must succeed before any test runs.

## 6. Attribution

* AI-generated commits must include `Assisted-by: <agent-name>` in the commit trailer.
* Format: `Assisted-by: <model-name>`.
* Human-authored commits do not need this tag.

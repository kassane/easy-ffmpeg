#!/usr/bin/env python3
"""Debug/audit helper: dry-run, exit codes, security, valgrind, gdb.

Usage:
  python3 scripts/debug.py              # all checks
  python3 scripts/debug.py --section dry-run   # one section
  python3 scripts/debug.py --json       # CI-friendly JSON output
"""
import subprocess, sys, os, re, json, argparse

BIN = "./easy-ffmpeg"
FIX = "tests/fixtures/in.mp4"
PASS = FAIL = 0
RESULTS = []

def run(cmd, timeout=30):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout + r.stderr

def check(desc, ok, detail=""):
    global PASS, FAIL
    if ok:
        PASS += 1; print(f"  ✓ {desc}")
    else:
        FAIL += 1; print(f"  ✗ {desc} — {detail}")
    RESULTS.append({"test": desc, "passed": ok, "detail": detail})

def section(name):
    print(f"\n=== {name} ===")

# ── All 18 subcommands: dry-run ──────────────────────────────────────────────
DRY_RUN_TESTS = [
    ("convert",       f"{BIN} convert {FIX} /tmp/o.mp4 --dry-run"),
    ("compress",      f"{BIN} compress {FIX} /tmp/o.mp4 --web --dry-run"),
    ("trim",          f"{BIN} trim {FIX} /tmp/o.mp4 --start 0 --duration 1 --dry-run"),
    ("resize",        f"{BIN} resize {FIX} /tmp/o.mp4 --scale hd --dry-run"),
    ("audio-extract", f"{BIN} audio-extract {FIX} /tmp/o.mp3 --dry-run"),
    ("probe",         f"{BIN} probe {FIX} --json --dry-run"),
    ("concat",        f"{BIN} concat {FIX} {FIX} /tmp/o.mp4 --copy --dry-run"),
    ("gif",           f"{BIN} gif {FIX} /tmp/o.gif --dry-run"),
    ("thumbnail",     f"{BIN} thumbnail {FIX} /tmp/o.jpg --dry-run"),
    ("speed",         f"{BIN} speed {FIX} /tmp/o.mp4 --factor 2.0 --dry-run"),
    ("rotate",        f"{BIN} rotate {FIX} /tmp/o.mp4 --angle 90 --dry-run"),
    ("watermark",     f"{BIN} watermark {FIX} /tmp/o.mp4 --image {FIX} --dry-run"),
    ("subtitle",      f"{BIN} subtitle {FIX} /tmp/o.mp4 --file tests/fixtures/in.srt --dry-run"),
    ("metadata",      f"{BIN} metadata {FIX} /tmp/o.mp4 --strip --dry-run"),
    ("normalize",     f"{BIN} normalize {FIX} /tmp/o.mp4 --dry-run"),
    ("replace-audio", f"{BIN} replace-audio {FIX} /tmp/o.mp4 --audio {FIX} --dry-run"),
    ("crop",          f"{BIN} crop {FIX} /tmp/o.mp4 --width 32 --height 32 --dry-run"),
    ("colordetect",   f"{BIN} colordetect {FIX} --dry-run"),
]

def test_dry_run():
    section("dry-run (all 18 commands)")
    for desc, cmd in DRY_RUN_TESTS:
        rc, out = run(cmd)
        has_cmd = "ffmpeg" in out or "ffprobe" in out
        check(desc, rc == 0 and has_cmd, f"rc={rc} ffmpeg_in_out={has_cmd}")

# ── Exit codes ────────────────────────────────────────────────────────────────
def test_exit_codes():
    section("exit codes")
    check("no args → 2",           run(f"{BIN}")[0] == 2)
    check("unknown command → 2",   run(f"{BIN} foobar")[0] == 2)
    check("missing input → 3",     run(f"{BIN} convert nope.mp4 /tmp/o.mp4")[0] == 3)
    check("--help → 0",            run(f"{BIN} --help")[0] == 0)
    check("-h → 0",                run(f"{BIN} -h")[0] == 0)
    check("--version → 0",         run(f"{BIN} --version")[0] == 0)
    check("-v → 0",                run(f"{BIN} -v")[0] == 0)

# ── Security: path traversal ──────────────────────────────────────────────────
def test_security_traversal():
    section("security: path traversal")
    check("traversal ../.. blocked",     run(f"{BIN} convert '../../etc/passwd' /tmp/o.mp4 --dry-run")[0] == 4)
    check("traversal dotdot blocked",    run(f"{BIN} convert 'foo/../../etc/shadow' /tmp/o.mp4 --dry-run")[0] == 4)
    check("traversal in compress",       run(f"{BIN} compress '../../etc/passwd' /tmp/o.mp4 --dry-run")[0] == 4)
    check("traversal in trim",           run(f"{BIN} trim '../../etc/passwd' /tmp/o.mp4 --start 0 --duration 1 --dry-run")[0] == 4)
    check("traversal in probe",          run(f"{BIN} probe '../../etc/passwd' --dry-run")[0] == 4)

# ── Security: injection characters ────────────────────────────────────────────
def test_security_injection():
    section("security: injection characters")
    check("quote in path blocked",   run(f"{BIN} convert \"foo'bar.mp4\" /tmp/o.mp4 --dry-run")[0] == 4)
    check("newline in path blocked", run(f"{BIN} convert $'foo\nbar.mp4' /tmp/o.mp4 --dry-run")[0] == 4)

# ── Security: device/special files ────────────────────────────────────────────
def test_security_devices():
    section("security: device/special files")
    check("/dev/null blocked",   run(f"{BIN} convert /dev/null /tmp/o.mp4 --dry-run")[0] == 3)
    check("/dev/zero blocked",   run(f"{BIN} convert /dev/zero /tmp/o.mp4 --dry-run")[0] == 3)
    check("directory blocked",   run(f"{BIN} convert /tmp /tmp/o.mp4 --dry-run")[0] == 3)

# ── Security: output validation ───────────────────────────────────────────────
def test_security_output():
    section("security: output validation")
    # Verify --dry-run prints command, not executes
    rc, out = run(f"{BIN} convert {FIX} /tmp/o.mp4 --dry-run")
    check("dry-run contains ffmpeg", "ffmpeg" in out, f"output={out[:80]}")
    check("dry-run no real execution", "exit code=0" not in out or "exit code=" not in out,
          "dry-run should print command only")
    # Verify --help doesn't leak internal paths
    rc, out = run(f"{BIN} --help")
    check("--help no internal paths", "/home/" not in out and "/root/" not in out,
          f"leaked path in --help")

# ── Valgrind: memcheck ────────────────────────────────────────────────────────
def test_valgrind():
    section("valgrind (memcheck)")
    for name, args in [("convert",  f"{FIX} /tmp/v.mp4"),
                       ("compress", f"{FIX} /tmp/v.mp4 --compress"),
                       ("trim",     f"{FIX} /tmp/v.mp4 --start 0 --duration 0.5"),
                       ("resize",   f"{FIX} /tmp/v.mp4 --scale hd"),
                       ("probe",    f"{FIX} --json")]:
        rc, out = run(f"valgrind --leak-check=full --error-exitcode=1 {BIN} {name} {args}", timeout=60)
        m = re.search(r'(\d+) allocs, (\d+) frees', out)
        if m:
            a, f = int(m.group(1)), int(m.group(2))
            check(f"{name}: {a}a/{f}f", a == f, f"LEAK {a-f}")
        else:
            check(f"{name}: valgrind ok", rc == 0, f"rc={rc}")

# ── GDB: crash backtrace ──────────────────────────────────────────────────────
def test_gdb():
    section("gdb (crash backtrace)")
    for name, args in [("convert", f"{FIX} /tmp/g.mp4"),
                       ("compress", f"{FIX} /tmp/g.mp4 --web")]:
        rc, out = run(f"gdb -batch -ex run -ex bt --args {BIN} {name} {args}", timeout=30)
        crashed = "SIGSEGV" in out or "SIGABRT" in out
        check(f"{name}: no crash", not crashed, "CRASHED" if crashed else "")

# ── Main ──────────────────────────────────────────────────────────────────────
SECTIONS = {
    "dry-run":      test_dry_run,
    "exit-codes":   test_exit_codes,
    "traversal":    test_security_traversal,
    "injection":    test_security_injection,
    "devices":      test_security_devices,
    "output":       test_security_output,
    "valgrind":     test_valgrind,
    "gdb":          test_gdb,
}

def main():
    parser = argparse.ArgumentParser(description="Debug/audit helper for easy-ffmpeg")
    parser.add_argument("--section", "-s", choices=list(SECTIONS.keys()),
                        help="Run only one section")
    parser.add_argument("--json", action="store_true", help="JSON output for CI")
    args = parser.parse_args()

    if args.section:
        SECTIONS[args.section]()
    else:
        for fn in SECTIONS.values():
            fn()

    print(f"\n{'='*40}")
    print(f"Results: {PASS} passed, {FAIL} failed")

    if args.json:
        print(json.dumps({"passed": PASS, "failed": FAIL, "results": RESULTS}, indent=2))

    sys.exit(1 if FAIL else 0)

if __name__ == "__main__":
    main()

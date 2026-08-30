#!/usr/bin/env python3
"""Debug helper: test all subcommands, valgrind, gdb backtrace on crash."""
import subprocess, sys, os, re

BIN = "./easy-ffmpeg"
FIX = "tests/fixtures/in.mp4"
PASS = FAIL = 0

def run(cmd, timeout=30):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout + r.stderr

def check(desc, ok, detail=""):
    global PASS, FAIL
    if ok:
        PASS += 1; print(f"  ✓ {desc}")
    else:
        FAIL += 1; print(f"  ✗ {desc} — {detail}")

print("=== dry-run ===")
tests = [
    ("convert",    f"{BIN} convert {FIX} /tmp/o.mp4 --dry-run"),
    ("compress",   f"{BIN} compress {FIX} /tmp/o.mp4 --web --dry-run"),
    ("trim",       f"{BIN} trim {FIX} /tmp/o.mp4 --start 0 --duration 1 --dry-run"),
    ("resize",     f"{BIN} resize {FIX} /tmp/o.mp4 --scale hd --dry-run"),
    ("audio-ext",  f"{BIN} audio-extract {FIX} /tmp/o.mp3 --dry-run"),
    ("probe",      f"{BIN} probe {FIX} --json --dry-run"),
]
for desc, cmd in tests:
    rc, out = run(cmd)
    check(desc, rc == 0 and "ffmpeg" in out or "ffprobe" in out, f"rc={rc}")

print("\n=== exit codes ===")
check("no args → 2",   run(f"{BIN}")[0] == 2)
check("unknown → 2",   run(f"{BIN} foobar")[0] == 2)
check("missing → 3",   run(f"{BIN} convert nope.mp4 /tmp/o.mp4")[0] == 3)
check("--help → 0",    run(f"{BIN} --help")[0] == 0)

print("\n=== valgrind ===")
for name, args in [("convert", f"{FIX} /tmp/v.mp4"),
                   ("compress", f"{FIX} /tmp/v.mp4 --compress"),
                   ("trim", f"{FIX} /tmp/v.mp4 --start 0 --duration 0.5"),
                   ("resize", f"{FIX} /tmp/v.mp4 --scale hd"),
                   ("audio-extract", f"{FIX} /tmp/v.mp3"),
                   ("probe", f"{FIX} --json")]:
    rc, out = run(f"valgrind --leak-check=full --error-exitcode=1 {BIN} {name} {args}", timeout=60)
    m = re.search(r'(\d+) allocs, (\d+) frees', out)
    if m:
        a, f = int(m.group(1)), int(m.group(2))
        check(f"{name}: {a}a/{f}f", a == f, f"LEAK {a-f}")
    else:
        check(f"{name}: valgrind ok", rc == 0, f"rc={rc}")

print("\n=== gdb backtrace ===")
for name, args in [("convert", f"{FIX} /tmp/g.mp4"),
                   ("compress", f"{FIX} /tmp/g.mp4 --web")]:
    rc, out = run(f"gdb -batch -ex run -ex bt --args {BIN} {name} {args}", timeout=30)
    crashed = "SIGSEGV" in out or "SIGABRT" in out
    check(f"{name}: no crash", not crashed, "CRASHED" if crashed else "")

print(f"\n{'='*40}")
print(f"Results: {PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)

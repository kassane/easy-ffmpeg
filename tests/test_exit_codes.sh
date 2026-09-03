#!/bin/sh
# TDD tests for exit codes.
# Run: sh tests/test_exit_codes.sh
PASS=0
FAIL=0
BIN=./easy-ffmpeg

check_exit() {
  desc="$1"; expected="$2"; shift 2
  actual=$(timeout 5 "$@" >/dev/null 2>&1; echo $?)
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc (exit=$actual)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc: expected=$expected got=$actual"
  fi
}

TMPID=$$

echo "=== success ==="
check_exit "convert" 0 $BIN convert tests/fixtures/in.mp4 /tmp/ec_out_$TMPID.mp4 --force --dry-run
check_exit "compress" 0 $BIN compress tests/fixtures/in.mp4 /tmp/ec_out_$TMPID.mp4 --web --force --dry-run
check_exit "trim" 0 $BIN trim tests/fixtures/in.mp4 /tmp/ec_out_$TMPID.mp4 --start 0 --duration 1 --force --dry-run
check_exit "resize" 0 $BIN resize tests/fixtures/in.mp4 /tmp/ec_out_$TMPID.mp4 --scale hd --force --dry-run
check_exit "audio-extract" 0 $BIN audio-extract tests/fixtures/in.mp4 /tmp/ec_out_$TMPID.mp3 --force --dry-run
check_exit "probe" 0 $BIN probe tests/fixtures/in.mp4 --json --dry-run

echo "=== errors ==="
check_exit "no args" 2 $BIN
check_exit "unknown cmd" 2 $BIN foobar
check_exit "missing file" 3 $BIN convert nonexistent.mp4 /tmp/ec_out_$TMPID.mp4 --dry-run
check_exit "missing input" 3 $BIN compress nonexistent.mp4 /tmp/ec_out_$TMPID.mp4 --dry-run

echo "=== security ==="
check_exit "path traversal blocked" 4 $BIN convert tests/fixtures/../../etc/passwd /tmp/ec_out_$TMPID.mp4 --dry-run
check_exit "device file blocked" 3 $BIN convert /dev/null /tmp/ec_out_$TMPID.mp4 --dry-run
check_exit "output traversal blocked" 4 $BIN convert tests/fixtures/in.mp4 /tmp/../../etc/evil.mp4 --dry-run

echo "=== help ==="
check_exit "--help" 0 $BIN --help
check_exit "compress --help" 0 $BIN compress --help

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1

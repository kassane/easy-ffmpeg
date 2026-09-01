#!/bin/sh
# TDD tests for progress tracking.
# Run: sh tests/test_progress.sh
PASS=0
FAIL=0
BIN=./easy-ffmpeg
FIX=tests/fixtures/in.mp4

check_progress() {
  desc="$1"; shift
  output=$("$@" 2>&1)
  case "$output" in
    *time=*|*frame=*|*###*|*100%*)
      PASS=$((PASS+1)); echo "  PASS: $desc (found progress output)"
      ;;
    *)
      FAIL=$((FAIL+1)); echo "  FAIL: $desc — no progress in: $output"
      ;;
  esac
}

echo "=== progress tracking ==="
check_progress "compress shows progress" $BIN compress $FIX /tmp/progress_test.mp4 --compress
check_progress "resize shows progress" $BIN resize $FIX /tmp/progress_test2.mp4 --scale hd
check_progress "trim shows progress" $BIN trim $FIX /tmp/progress_test3.mp4 --start 0 --duration 0.5

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1

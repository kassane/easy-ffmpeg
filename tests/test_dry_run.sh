#!/bin/sh
# TDD tests for easy-ffmpeg --dry-run output.
# Run: sh tests/test_dry_run.sh
set -e

PASS=0
FAIL=0
BIN=./easy-ffmpeg
FIX=tests/fixtures/in.mp4

pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

check_contains() {
  desc="$1"; shift
  expected="$1"; shift
  got="$*"
  case "$got" in
    *"$expected"*) pass "$desc";;
    *) fail "$desc — expected '$expected' in: $got";;
  esac
}

check_not_contains() {
  desc="$1"; shift
  forbidden="$1"; shift
  got="$*"
  case "$got" in
    *"$forbidden"*) fail "$desc — should NOT contain '$forbidden' in: $got";;
    *) pass "$desc";;
  esac
}

echo "=== convert ==="
OUT=$($BIN convert $FIX /tmp/o.mp4 --dry-run 2>&1)
check_contains "convert uses input flag" "-i $FIX" "$OUT"
check_contains "convert has output" "/tmp/o.mp4" "$OUT"

OUT=$($BIN convert $FIX /tmp/o.mp4 --codec h264 --dry-run 2>&1)
check_contains "convert --codec h264" "-c:v h264" "$OUT"

echo "=== compress presets ==="
OUT=$($BIN compress $FIX /tmp/o.mp4 --web --dry-run 2>&1)
check_contains "web: libx264" "-c:v libx264" "$OUT"
check_contains "web: crf 23" "-crf 23" "$OUT"
check_contains "web: faststart" "+faststart" "$OUT"

OUT=$($BIN compress $FIX /tmp/o.mp4 --mobile --dry-run 2>&1)
check_contains "mobile: libx264" "-c:v libx264" "$OUT"
check_contains "mobile: scale 720" "scale=-2:720" "$OUT"
check_contains "mobile: crf 26" "-crf 26" "$OUT"

OUT=$($BIN compress $FIX /tmp/o.mp4 --streaming --dry-run 2>&1)
check_contains "streaming: libx265" "-c:v libx265" "$OUT"
check_contains "streaming: crf 18" "-crf 18" "$OUT"

OUT=$($BIN compress $FIX /tmp/o.mp4 --compress --dry-run 2>&1)
check_contains "compress: libx265" "-c:v libx265" "$OUT"
check_contains "compress: crf 28" "-crf 28" "$OUT"

echo "=== trim ==="
OUT=$($BIN trim $FIX /tmp/o.mp4 --start 00:00:00 --duration 0.5 --dry-run 2>&1)
check_contains "trim: -ss flag" "-ss 00:00:00" "$OUT"
check_contains "trim: -t flag" "-t 0.5" "$OUT"
check_contains "trim: input before output" "-i $FIX" "$OUT"

OUT=$($BIN trim $FIX /tmp/o.mp4 --start 0 --duration 1 --copy --dry-run 2>&1)
check_contains "trim --copy: -c:v copy" "-c:v copy" "$OUT"
check_contains "trim --copy: -c:a copy" "-c:a copy" "$OUT"

echo "=== resize ==="
OUT=$($BIN resize $FIX /tmp/o.mp4 --scale hd --dry-run 2>&1)
check_contains "resize hd: scale 720" "scale=-2:720" "$OUT"

OUT=$($BIN resize $FIX /tmp/o.mp4 --scale fullhd --dry-run 2>&1)
check_contains "resize fullhd: scale 1080" "scale=-2:1080" "$OUT"

OUT=$($BIN resize $FIX /tmp/o.mp4 --width 320 --height 240 --dry-run 2>&1)
check_contains "resize manual: scale 320:240" "scale=320:240" "$OUT"

echo "=== audio-extract ==="
OUT=$($BIN audio-extract $FIX /tmp/o.mp3 --dry-run 2>&1)
check_contains "audio-extract: -vn" "-vn" "$OUT"
check_contains "audio-extract: mp3 codec" "-c:a libmp3lame" "$OUT"

echo "=== probe ==="
OUT=$($BIN probe $FIX --json --dry-run 2>&1)
check_contains "probe: ffprobe binary" "ffprobe" "$OUT"
check_contains "probe: show_streams" "show_streams" "$OUT"

echo ""
echo "=== smart remux (convert h264+aac → mp4) ==="
OUT=$($BIN convert $FIX /tmp/o.mp4 --dry-run 2>&1)
check_contains "smart remux: -c:v copy" "-c:v copy" "$OUT"
check_contains "smart remux: -c:a copy" "-c:a copy" "$OUT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1

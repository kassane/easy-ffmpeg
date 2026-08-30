#!/bin/sh
# Smoke tests: real ffmpeg execution against fixtures/in.mp4.
# Run: sh tests/smoke.sh
set -e

PASS=0
FAIL=0
BIN=./easy-ffmpeg
FIX=tests/fixtures/in.mp4
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

check_file() {
  desc="$1"; path="$2"; min_bytes="${3:-100}"
  if [ -f "$path" ]; then
    size=$(wc -c < "$path")
    if [ "$size" -ge "$min_bytes" ]; then
      pass "$desc ($size bytes)"
    else
      fail "$desc: too small ($size bytes)"
    fi
  else
    fail "$desc: file not created"
  fi
}

check_exit() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    pass "$desc (exit=$actual)"
  else
    fail "$desc: expected exit=$expected, got $actual"
  fi
}

echo "=== convert (smart remux) ==="
$BIN convert $FIX $TMPDIR/convert.mp4 2>/dev/null
check_file "convert smart remux" $TMPDIR/convert.mp4 100

$BIN convert $FIX $TMPDIR/convert_h265.mp4 --codec libx265 2>/dev/null
check_file "convert to h265" $TMPDIR/convert_h265.mp4 100

echo "=== compress presets ==="
$BIN compress $FIX $TMPDIR/compress_web.mp4 --web 2>/dev/null
check_file "compress --web" $TMPDIR/compress_web.mp4 100

$BIN compress $FIX $TMPDIR/compress_mobile.mp4 --mobile 2>/dev/null
check_file "compress --mobile" $TMPDIR/compress_mobile.mp4 100

$BIN compress $FIX $TMPDIR/compress_stream.mp4 --streaming 2>/dev/null
check_file "compress --streaming" $TMPDIR/compress_stream.mp4 100

$BIN compress $FIX $TMPDIR/compress_def.mp4 --compress 2>/dev/null
check_file "compress --compress" $TMPDIR/compress_def.mp4 100

echo "=== trim ==="
$BIN trim $FIX $TMPDIR/trim.mp4 --start 00:00:00 --duration 0.5 2>/dev/null
check_file "trim --duration" $TMPDIR/trim.mp4 100

$BIN trim $FIX $TMPDIR/trim_copy.mp4 --start 0 --duration 1 --copy 2>/dev/null
check_file "trim --copy" $TMPDIR/trim_copy.mp4 100

echo "=== resize ==="
$BIN resize $FIX $TMPDIR/resize_hd.mp4 --scale hd 2>/dev/null
check_file "resize --scale hd" $TMPDIR/resize_hd.mp4 100

$BIN resize $FIX $TMPDIR/resize_fullhd.mp4 --scale fullhd 2>/dev/null
check_file "resize --scale fullhd" $TMPDIR/resize_fullhd.mp4 100

$BIN resize $FIX $TMPDIR/resize_manual.mp4 --width 32 --height 32 2>/dev/null
check_file "resize manual 32x32" $TMPDIR/resize_manual.mp4 100

echo "=== audio-extract ==="
$BIN audio-extract $FIX $TMPDIR/audio.mp3 2>/dev/null
check_file "audio-extract mp3" $TMPDIR/audio.mp3 100

echo "=== probe ==="
$BIN probe $FIX --json > $TMPDIR/probe.json 2>/dev/null
check_file "probe --json" $TMPDIR/probe.json 10

echo "=== error handling ==="
set +e
$BIN convert nonexistent.mp4 /tmp/o.mp4 >/dev/null 2>&1
check_exit "convert missing file" 3 $?
set -e

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1

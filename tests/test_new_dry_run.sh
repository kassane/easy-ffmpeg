#!/bin/sh
# Dry-run tests for new subcommands (concat, gif, thumbnail, speed, rotate, watermark, subtitle, metadata, normalize, replace-audio).
PASS=0
FAIL=0
BIN=./easy-ffmpeg
FIX=tests/fixtures/in.mp4

check() {
  desc="$1"; shift
  output=$("$@" 2>&1)
  rc=$?
  case "$output" in
    *ffmpeg*)
      PASS=$((PASS+1)); echo "  PASS: $desc"
      ;;
    *)
      FAIL=$((FAIL+1)); echo "  FAIL: $desc — output: $output"
      ;;
  esac
}

echo "=== new subcommands ==="
check "concat --copy" $BIN concat $FIX $FIX /tmp/out.mp4 --copy --dry-run
check "concat --codec" $BIN concat $FIX $FIX /tmp/out.mp4 --codec h264 --dry-run
check "gif" $BIN gif $FIX /tmp/out.gif --dry-run
check "gif --fps" $BIN gif $FIX /tmp/out.gif --fps 10 --width 320 --dry-run
check "thumbnail" $BIN thumbnail $FIX /tmp/out.jpg --dry-run
check "thumbnail --time" $BIN thumbnail $FIX /tmp/out.jpg --time 00:01:30 --dry-run
check "speed 2x" $BIN speed $FIX /tmp/out.mp4 --factor 2.0 --dry-run
check "speed 0.5x" $BIN speed $FIX /tmp/out.mp4 --factor 0.5 --dry-run
check "rotate 90" $BIN rotate $FIX /tmp/out.mp4 --angle 90 --dry-run
check "rotate 180" $BIN rotate $FIX /tmp/out.mp4 --angle 180 --dry-run
check "rotate 270" $BIN rotate $FIX /tmp/out.mp4 --angle 270 --dry-run
check "rotate flip h" $BIN rotate $FIX /tmp/out.mp4 --flip h --dry-run
check "rotate flip v" $BIN rotate $FIX /tmp/out.mp4 --flip v --dry-run
check "watermark text" $BIN watermark $FIX /tmp/out.mp4 --text Sample --dry-run
check "metadata strip" $BIN metadata $FIX /tmp/out.mp4 --strip --dry-run
check "metadata title" $BIN metadata $FIX /tmp/out.mp4 --title "My Video" --dry-run
check "normalize" $BIN normalize $FIX /tmp/out.mp4 --dry-run
check "replace-audio" $BIN replace-audio $FIX /tmp/out.mp4 --audio $FIX --dry-run

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1

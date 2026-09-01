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

OUT=$($BIN compress $FIX /tmp/o.mp4 --av1 --dry-run 2>&1)
check_contains "av1: libsvtav1" "-c:v libsvtav1" "$OUT"
check_contains "av1: crf 30" "-crf 30" "$OUT"

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

echo "=== concat ==="
OUT=$($BIN concat $FIX $FIX /tmp/o.mp4 --copy --dry-run 2>&1)
check_contains "concat --copy: -c:v copy" "-c:v copy" "$OUT"
check_contains "concat --copy: format concat" "-f concat" "$OUT"

OUT=$($BIN concat $FIX $FIX /tmp/o.mp4 --codec h264 --dry-run 2>&1)
check_contains "concat --codec: -c:v h264" "-c:v h264" "$OUT"

echo "=== gif ==="
OUT=$($BIN gif $FIX /tmp/o.gif --dry-run 2>&1)
check_contains "gif: fps filter" "fps=" "$OUT"
check_contains "gif: scale filter" "scale=" "$OUT"

OUT=$($BIN gif $FIX /tmp/o.gif --fps 10 --width 320 --dry-run 2>&1)
check_contains "gif --fps 10: fps=10" "fps=10" "$OUT"
check_contains "gif --width 320: scale=320" "scale=320" "$OUT"

echo "=== thumbnail ==="
OUT=$($BIN thumbnail $FIX /tmp/o.jpg --dry-run 2>&1)
check_contains "thumbnail: -vframes 1" "-vframes 1" "$OUT"

OUT=$($BIN thumbnail $FIX /tmp/o.jpg --time 00:01:30 --dry-run 2>&1)
check_contains "thumbnail --time: -ss 00:01:30" "-ss 00:01:30" "$OUT"

echo "=== speed ==="
OUT=$($BIN speed $FIX /tmp/o.mp4 --factor 2.0 --dry-run 2>&1)
check_contains "speed 2x: setpts" "setpts=" "$OUT"
check_contains "speed 2x: atempo" "atempo=" "$OUT"

OUT=$($BIN speed $FIX /tmp/o.mp4 --factor 0.5 --dry-run 2>&1)
check_contains "speed 0.5x: atempo" "atempo=" "$OUT"

echo "=== rotate ==="
OUT=$($BIN rotate $FIX /tmp/o.mp4 --angle 90 --dry-run 2>&1)
check_contains "rotate 90: transpose" "transpose=1" "$OUT"

OUT=$($BIN rotate $FIX /tmp/o.mp4 --angle 180 --dry-run 2>&1)
check_contains "rotate 180: double transpose" "transpose=1,transpose=1" "$OUT"

OUT=$($BIN rotate $FIX /tmp/o.mp4 --angle 270 --dry-run 2>&1)
check_contains "rotate 270: transpose=2" "transpose=2" "$OUT"

OUT=$($BIN rotate $FIX /tmp/o.mp4 --flip h --dry-run 2>&1)
check_contains "rotate flip h: hflip" "hflip" "$OUT"

OUT=$($BIN rotate $FIX /tmp/o.mp4 --flip v --dry-run 2>&1)
check_contains "rotate flip v: vflip" "vflip" "$OUT"

echo "=== watermark ==="
OUT=$($BIN watermark $FIX /tmp/o.mp4 --text Sample --dry-run 2>&1)
check_contains "watermark text: drawtext" "drawtext" "$OUT"

echo "=== subtitle ==="
OUT=$($BIN subtitle $FIX /tmp/o.mp4 --file tests/fixtures/in.srt --dry-run 2>&1)
check_contains "subtitle: subtitles filter" "subtitles=" "$OUT"

echo "=== metadata ==="
OUT=$($BIN metadata $FIX /tmp/o.mp4 --strip --dry-run 2>&1)
check_contains "metadata strip: -map_metadata -1" "-map_metadata -1" "$OUT"

OUT=$($BIN metadata $FIX /tmp/o.mp4 --title "My Video" --dry-run 2>&1)
check_contains "metadata title: -metadata" "-metadata" "$OUT"

echo "=== normalize ==="
OUT=$($BIN normalize $FIX /tmp/o.mp4 --dry-run 2>&1)
check_contains "normalize: loudnorm" "loudnorm" "$OUT"

echo "=== replace-audio ==="
OUT=$($BIN replace-audio $FIX /tmp/o.mp4 --audio $FIX --dry-run 2>&1)
check_contains "replace-audio: -map 0:v" "-map 0:v" "$OUT"
check_contains "replace-audio: -map 1:a" "-map 1:a" "$OUT"

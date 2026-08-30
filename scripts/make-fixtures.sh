#!/bin/sh
# Regenerate tests/fixtures/in.mp4 (tiny hermetic clip) so smoke tests have input.
set -eu
. "$(dirname "$0")/env.sh"
ROOT="$EASY_FFMPEG_ROOT"
mkdir -p "$ROOT/tests/fixtures"
"$FFMPEG_BIN" -y -f lavfi -i testsrc=d=1:s=64x64:r=10 \
  -f lavfi -i sine=f=440:d=1 \
  -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac \
  "$ROOT/tests/fixtures/in.mp4" >/dev/null 2>&1
echo "[make-fixtures] wrote tests/fixtures/in.mp4 ($("$FFPROBE_BIN" -v error -show_entries format=duration -of default=nw=1:nk=1 "$ROOT/tests/fixtures/in.mp4")s)"

#!/bin/sh
# Regenerate test fixtures so smoke tests have input.
set -eu
. "$(dirname "$0")/env.sh"
ROOT="$EASY_FFMPEG_ROOT"
mkdir -p "$ROOT/tests/fixtures"

# in.mp4: 1s, 64x64, h264+aac (basic fixture)
"$FFMPEG_BIN" -y -f lavfi -i testsrc=d=1:s=64x64:r=10 \
  -f lavfi -i sine=f=440:d=1 \
  -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac \
  "$ROOT/tests/fixtures/in.mp4" >/dev/null 2>&1

# in_h265.mp4: 1s, 64x64, hevc+aac (codec detection testing)
"$FFMPEG_BIN" -y -f lavfi -i testsrc=d=1:s=64x64:r=10 \
  -f lavfi -i sine=f=440:d=1 \
  -shortest -c:v libx265 -pix_fmt yuv420p -c:a aac \
  "$ROOT/tests/fixtures/in_h265.mp4" >/dev/null 2>&1

# in_hd.mp4: 3s, 1280x720, h264+aac (resize/crop testing)
"$FFMPEG_BIN" -y -f lavfi -i testsrc=d=3:s=1280x720:r=10 \
  -f lavfi -i sine=f=440:d=3 \
  -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac \
  "$ROOT/tests/fixtures/in_hd.mp4" >/dev/null 2>&1

# in_odd.mp4: 1s, 63x63, h264+aac (odd dimensions for normalization test)
"$FFMPEG_BIN" -y -f lavfi -i testsrc=d=1:s=63x63:r=10 \
  -f lavfi -i sine=f=440:d=1 \
  -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac \
  "$ROOT/tests/fixtures/in_odd.mp4" >/dev/null 2>&1

echo "[make-fixtures] wrote 4 fixtures in tests/fixtures/"

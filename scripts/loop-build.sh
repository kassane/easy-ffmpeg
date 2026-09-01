#!/bin/sh
# Loop engineering build gate: carbon build + smoke, or one-shot verify.
#   scripts/loop-build.sh --once      -> single green check (exit 0/1)
#   scripts/loop-build.sh [--watch]   -> infinite loop (loop-engineering Grill)
set -eu
. "$(dirname "$0")/env.sh"
OUT=/tmp/easy-ffmpeg
# Collect source files; skip globs that expand to themselves (no files yet)
collect_src() {
  local files="src/main.carbon"
  for g in src/core/*.carbon src/cli/*.carbon; do
    [ -e "$g" ] && files="$files $g"
  done
  echo "$files"
}

build_once() {
  local SRC
  SRC="$(collect_src)"
  # -Isrc/core is required: custom headers (ffi_helper.hpp) are referenced via
  # `import Cpp library "ffi_helper.hpp"` and must be found at compile time.
  "$CARBON" build $SRC --output="$OUT" -- -std=c++23 -Isrc/core
  # Phase 0: just verify binary runs (exit 0). Phase 2+ adds --help grep + smoke.
  "$OUT" >/dev/null 2>&1
  echo "[green] $(date -u +%FT%TZ)"
}

if [ "${1:-}" = "--once" ]; then
  build_once
  exit 0
fi
# watch mode: keep looping; sleep fallback if inotifywait absent
while true; do
  if build_once; then :; else
    echo "[red] $(date -u +%FT%TZ)" >&2
    sleep 1
  fi
  if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -rq -e modify,close_write "$EASY_FFMPEG_ROOT/src" 2>/dev/null || true
  else
    # ponytail: no inotify -> poll every 2s; switch to notify when available
    sleep 2
  fi
done

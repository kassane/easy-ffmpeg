#!/bin/sh
# Resolve Carbon toolchain + ffmpeg in one source.
# Run from the repo root (all scripts in scripts/ do). Usage: . ./scripts/env.sh
export EASY_FFMPEG_ROOT="$(pwd)"
export CARBON="$EASY_FFMPEG_ROOT/carbon_toolchain-0.0.0-0.nightly.2026.08.29/bin/carbon"
export FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"
export FFPROBE_BIN="${FFPROBE_BIN:-ffprobe}"
# Sanity: must be a valid Carbon tree; fail fast with clear message.
if [ ! -x "$CARBON" ]; then
  echo "Carbon toolchain not found at $CARBON — run from repo root" >&2
  return 127
fi
command -v "$FFMPEG_BIN" >/dev/null 2>&1 || { echo "ffmpeg not found (set FFMPEG_BIN)" >&2; return 127; }
command -v "$FFPROBE_BIN" >/dev/null 2>&1 || { echo "ffprobe not found (set FFPROBE_BIN)" >&2; return 127; }

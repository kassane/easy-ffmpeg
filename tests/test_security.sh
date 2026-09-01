#!/bin/sh
# Security TDD tests — injection, traversal, boundary, exit codes.
# Run: sh tests/test_security.sh
PASS=0
FAIL=0
BIN=./easy-ffmpeg
FIX=tests/fixtures/in.mp4

check_exit() {
  desc="$1"; expected="$2"; shift 2
  actual=$(timeout 5 "$@" >/dev/null 2>&1; echo $?)
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc (exit=$actual)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc: expected=$expected got=$actual"
  fi
}

check_contains() {
  desc="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if echo "$out" | grep -q "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc — '$needle' not in output"
  fi
}

echo "=== path traversal ==="
check_exit "traversal ../.. blocked" 4 $BIN convert "../../etc/passwd" /tmp/o.mp4 --dry-run
check_exit "absolute path dry-run ok" 0 $BIN convert "/etc/passwd" /tmp/o.mp4 --dry-run
check_exit "traversal dotdot blocked" 4 $BIN convert "foo/../../etc/shadow" /tmp/o.mp4 --dry-run
check_exit "traversal in compress" 4 $BIN compress "../../etc/passwd" /tmp/o.mp4 --dry-run
check_exit "traversal in trim" 4 $BIN trim "../../etc/passwd" /tmp/o.mp4 --start 0 --duration 1 --dry-run
check_exit "traversal in probe" 4 $BIN probe "../../etc/passwd" --dry-run

echo "=== injection characters ==="
check_exit "quote in path blocked" 4 $BIN convert "foo'bar.mp4" /tmp/o.mp4 --dry-run
check_exit "newline in path blocked" 4 $BIN convert "foo
bar.mp4" /tmp/o.mp4 --dry-run

echo "=== device/special files ==="
check_exit "device /dev/null blocked" 3 $BIN convert /dev/null /tmp/o.mp4 --dry-run
check_exit "device /dev/zero blocked" 3 $BIN convert /dev/zero /tmp/o.mp4 --dry-run
check_exit "directory as input blocked" 3 $BIN convert /tmp /tmp/o.mp4 --dry-run

echo "=== missing arguments ==="
check_exit "no args exit 2" 2 $BIN
check_exit "unknown command exit 2" 2 $BIN foobar
check_exit "convert missing input" 3 $BIN convert nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "compress missing input" 3 $BIN compress nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "trim missing input" 3 $BIN trim nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "resize missing input" 3 $BIN resize nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "audio-extract missing input" 3 $BIN audio-extract nonexistent.mp4 /tmp/o.mp3 --dry-run
check_exit "probe missing input" 3 $BIN probe nonexistent.mp4 --dry-run
check_exit "gif missing input" 3 $BIN gif nonexistent.mp4 /tmp/o.gif --dry-run
check_exit "thumbnail missing input" 3 $BIN thumbnail nonexistent.mp4 /tmp/o.jpg --dry-run
check_exit "speed missing input" 3 $BIN speed nonexistent.mp4 /tmp/o.mp4 --factor 2.0 --dry-run
check_exit "rotate missing input" 3 $BIN rotate nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "watermark missing input" 3 $BIN watermark nonexistent.mp4 /tmp/o.mp4 --image logo.png --dry-run
check_exit "subtitle missing input" 3 $BIN subtitle nonexistent.mp4 /tmp/o.mp4 --file sub.srt --dry-run
check_exit "metadata missing input" 3 $BIN metadata nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "normalize missing input" 3 $BIN normalize nonexistent.mp4 /tmp/o.mp4 --dry-run
check_exit "replace-audio missing input" 3 $BIN replace-audio nonexistent.mp4 /tmp/o.mp4 --audio music.mp3 --dry-run

echo "=== valid inputs succeed ==="
check_exit "convert valid" 0 $BIN convert $FIX /tmp/o.mp4 --dry-run
check_exit "compress valid" 0 $BIN compress $FIX /tmp/o.mp4 --web --dry-run
check_exit "trim valid" 0 $BIN trim $FIX /tmp/o.mp4 --start 0 --duration 1 --dry-run
check_exit "resize valid" 0 $BIN resize $FIX /tmp/o.mp4 --scale hd --dry-run
check_exit "audio-extract valid" 0 $BIN audio-extract $FIX /tmp/o.mp3 --dry-run
check_exit "probe valid" 0 $BIN probe $FIX --json --dry-run
check_exit "gif valid" 0 $BIN gif $FIX /tmp/o.gif --dry-run
check_exit "thumbnail valid" 0 $BIN thumbnail $FIX /tmp/o.jpg --dry-run
check_exit "speed valid" 0 $BIN speed $FIX /tmp/o.mp4 --factor 2.0 --dry-run
check_exit "rotate valid" 0 $BIN rotate $FIX /tmp/o.mp4 --angle 90 --dry-run
check_exit "metadata valid" 0 $BIN metadata $FIX /tmp/o.mp4 --strip --dry-run
check_exit "normalize valid" 0 $BIN normalize $FIX /tmp/o.mp4 --dry-run
check_exit "crop valid" 0 $BIN crop $FIX /tmp/o.mp4 --width 320 --height 240 --dry-run

echo "=== help flags ==="
check_exit "--help" 0 $BIN --help
check_exit "-h" 0 $BIN -h
check_exit "--version" 0 $BIN --version
check_exit "-v" 0 $BIN -v
check_exit "convert --help" 0 $BIN convert --help
check_exit "compress --help" 0 $BIN compress --help
check_exit "trim --help" 0 $BIN trim --help
check_exit "resize --help" 0 $BIN resize --help
check_exit "audio-extract --help" 0 $BIN audio-extract --help
check_exit "probe --help" 0 $BIN probe --help

echo ""
echo "Results: $PASS passed, $FAIL failed"
check_exit "crop missing input" 3 $BIN crop nonexistent.mp4 /tmp/o.mp4 --width 320 --height 240 --dry-run
check_exit "colordetect missing input" 3 $BIN colordetect nonexistent.mp4 --dry-run
check_exit "colordetect valid" 0 $BIN colordetect $FIX --dry-run

[ "$FAIL" = "0" ] || exit 1

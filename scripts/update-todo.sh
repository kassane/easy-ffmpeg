#!/bin/sh
# Regenerate docs/TODO.md from docs/PLAN.md checkboxes under "## Phase N —" headers.
#   scripts/update-todo.sh          -> rewrite docs/TODO.md
#   scripts/update-todo.sh --check  -> exit 1 if stale (CI/pre-commit)
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PLAN="$ROOT/docs/PLAN.md"
TODO="$ROOT/docs/TODO.md"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "${1:-}" = "--check" ]; then
  # Regenerate to temp, compare with existing
  : > /tmp/todo_check.$$
  n=0; phase=""
  while IFS= read -r line; do
    case "$line" in
      '## Phase '*)
        phase="${line#### }"
        ;;
      '## '*)
        phase=""
        ;;
      '- [ ] '*)
        [ -n "$phase" ] || continue
        task="${line#- \[ \] }"
        printf '| %s | %s | %s | pending |
' "$n" "$phase" "$task" >> /tmp/todo_check.$$
        n=$((n+1))
        ;;
      '- [x] '*)
        [ -n "$phase" ] || continue
        task="${line#- \[x\] }"
        printf '| %s | %s | %s | done |
' "$n" "$phase" "$task" >> /tmp/todo_check.$$
        n=$((n+1))
        ;;
    esac
  done < "$PLAN"
  # Build expected TODO content
  STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  {
    printf '# Todo — easy-ffmpeg

'
    printf '> **Auto-generated.** Do NOT hand-edit the table body. Source: `docs/PLAN.md`.

'
    printf 'Last updated: %s | Source: docs/PLAN.md

' "$STAMP"
    printf '| # | Phase | Task | Status |
|---|-------|------|--------|
'
    cat /tmp/todo_check.$$
  } > /tmp/todo_expected.$$
  rm -f /tmp/todo_check.$$
  # Compare (ignore timestamp line)
  if diff -q <(grep -v 'Last updated:' "$TODO") <(grep -v 'Last updated:' /tmp/todo_expected.$$) >/dev/null 2>&1; then
    echo "[update-todo] docs/TODO.md is current"
    rm -f /tmp/todo_expected.$$
    exit 0
  else
    echo "docs/TODO.md stale — run ./scripts/update-todo.sh" >&2
    rm -f /tmp/todo_expected.$$
    exit 1
  fi
fi

# Aggregate only items nested under a "## Phase N —" heading.
# Any other section header resets the current phase (checklist/todo lists are skipped).
: > /tmp/todo.$$
n=0; phase=""
while IFS= read -r line; do
  case "$line" in
    '## Phase '*)
      phase="${line#### }"      # e.g. "Phase 0 — Scaffolding (Day 0, 2h)"
      ;;
    '## '*)
      phase=""                  # non-phase section: skip its checkboxes
      ;;
    '- [ ] '*)
      [ -n "$phase" ] || continue
      task="${line#- \[ \] }"
      printf '| %s | %s | %s | pending |\n' "$n" "$phase" "$task" >> /tmp/todo.$$
      n=$((n+1))
      ;;
    '- [x] '*)
      [ -n "$phase" ] || continue
      task="${line#- \[x\] }"
      printf '| %s | %s | %s | done |\n' "$n" "$phase" "$task" >> /tmp/todo.$$
      n=$((n+1))
      ;;
  esac
done < "$PLAN"

{
  printf '# Todo — easy-ffmpeg\n\n'
  printf '> **Auto-generated.** Do NOT hand-edit the table body. Source: `docs/PLAN.md`.\n\n'
  printf 'Last updated: %s | Source: docs/PLAN.md\n\n' "$STAMP"
  printf '| # | Phase | Task | Status |\n|---|-------|------|--------|\n'
  cat /tmp/todo.$$
} > "$TODO"
rm -f /tmp/todo.$$

if [ "${1:-}" = "--check" ]; then
  git -C "$ROOT" diff --exit-code --quiet -- docs/TODO.md \
    || { echo "docs/TODO.md stale — run ./scripts/update-todo.sh" >&2; exit 1; }
fi
echo "[update-todo] docs/TODO.md regenerated ($n tasks)"

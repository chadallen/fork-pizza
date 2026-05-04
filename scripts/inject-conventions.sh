#!/usr/bin/env bash
# Claude Workflow — SessionStart hook
# Injects workflow conventions into Claude context each session.
# Checks for the bd prerequisite and emits a soft install hint if missing.
# Always exits 0 to avoid blocking the session.

CONVENTIONS="${CLAUDE_PLUGIN_ROOT}/docs/conventions.md"

if ! command -v bd >/dev/null 2>&1; then
  echo "⚠️  Beads (bd) not found on PATH."
  echo "   macOS: brew install beads"
  echo "   Other: https://github.com/steveyegge/beads"
  echo "   Run /fork-pizza:start-session after installing."
  exit 0
fi

if [ -f "$CONVENTIONS" ]; then
  cat "$CONVENTIONS"
fi

exit 0

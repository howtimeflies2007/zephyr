#!/usr/bin/env bash
# .claude/hooks/check-readonly-violation.sh
#
# PostToolUse hook for Edit / Write. If somehow a read-only path got
# modified (settings.json deny should prevent this, but defense in
# depth), surface it loudly so the user notices before commit.

set -euo pipefail

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    PATH_TOUCHED=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')
else
    PATH_TOUCHED=$(echo "$INPUT" | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//; s/"$//')
fi

if [ -z "$PATH_TOUCHED" ]; then
    exit 0
fi

# Patterns that should never be edited during analysis
case "$PATH_TOUCHED" in
    subsys/bluetooth/*|*/subsys/bluetooth/*)        VIOLATION=1 ;;
    drivers/bluetooth/*|*/drivers/bluetooth/*)      VIOLATION=1 ;;
    include/zephyr/bluetooth/*|*/include/zephyr/bluetooth/*) VIOLATION=1 ;;
    doc/connectivity/bluetooth/*|*/doc/connectivity/bluetooth/*) VIOLATION=1 ;;
    *)                                              VIOLATION=0 ;;
esac

# CLAUDE.md files inside read-only trees are exceptions — they're our additions
case "$PATH_TOUCHED" in
    */CLAUDE.md)  VIOLATION=0 ;;
esac

if [ "$VIOLATION" -eq 1 ]; then
    echo >&2
    echo "⚠ READ-ONLY VIOLATION DETECTED" >&2
    echo "  Path: $PATH_TOUCHED" >&2
    echo "  This file is in a read-only tree per the analysis plan." >&2
    echo "  Inspect with:  git diff -- $PATH_TOUCHED" >&2
    echo "  Revert with:   git checkout -- $PATH_TOUCHED" >&2
    echo >&2
    # Don't exit non-zero — the edit already happened; this is just a loud warning
fi

exit 0

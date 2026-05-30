#!/usr/bin/env bash
# .claude/hooks/guard-upstream-push.sh
#
# PreToolUse hook for Bash commands. Reads the proposed command from
# stdin (as JSON) and blocks pushes to a remote that looks like upstream.
#
# Defense in depth: settings.json already denies "git push:*", but if
# someone ever relaxes that, this hook catches the specific dangerous case.

set -euo pipefail

# Read JSON input from stdin. Format (Claude Code hook spec):
#   {"tool_input": {"command": "git push origin main", ...}, ...}
INPUT=$(cat)

# Extract the command string. Fallback gracefully if jq isn't installed.
if command -v jq >/dev/null 2>&1; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
else
    # Crude grep fallback
    CMD=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//; s/"$//')
fi

# Not a git push? Allow.
if ! echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push'; then
    exit 0
fi

# Identify which remote is targeted.
# Cases: `git push`, `git push <remote>`, `git push <remote> <branch>`, `git push --force`
REMOTE=$(echo "$CMD" | awk '{
    for (i=3; i<=NF; i++) {
        if ($i !~ /^-/) { print $i; exit }
    }
}')

# `git push` with no remote uses the configured upstream — check that too
if [ -z "$REMOTE" ]; then
    REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || echo "")
fi

if [ -z "$REMOTE" ]; then
    # Can't determine — allow, the deny rule in settings.json will catch it
    exit 0
fi

# Look up the remote URL
URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")

# Block if URL looks like upstream Zephyr
if echo "$URL" | grep -qiE 'github\.com[:/]zephyrproject-rtos/zephyr'; then
    echo "BLOCKED: refusing to push to upstream Zephyr ($URL)" >&2
    echo "         Analysis branches must only be pushed to your fork." >&2
    echo "         If this is intentional, push manually from a shell." >&2
    exit 1
fi

exit 0

#!/usr/bin/env bash
# .claude/hooks/inject-context.sh
#
# UserPromptSubmit hook. Adds a brief reminder to Claude's context about
# the currently pinned analysis SHA and the active phase. Helps the model
# stay anchored across long sessions without the user having to repeat it.
#
# Output to stdout becomes additional context. Keep it short.

set -euo pipefail

ORIENTATION="docs/ble-analysis/00-orientation.md"

if [ ! -f "$ORIENTATION" ]; then
    # Phase 0 not done yet — nothing to inject
    exit 0
fi

SHA=$(grep -m1 '^Revision:' "$ORIENTATION" 2>/dev/null | awk '{print $2}' || echo "")
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")

if [ -z "$SHA" ]; then
    exit 0
fi

echo "[analysis-context]"
echo "Pinned SHA: $SHA"
if [ -n "$CURRENT_HEAD" ] && [ "$SHA" != "$CURRENT_HEAD" ]; then
    echo "⚠ HEAD ($CURRENT_HEAD) differs from pinned SHA — file:line citations may drift."
fi
echo "Build mode: ${BLE_ANALYSIS_BUILD_MODE:-combined} (canonical for this analysis)"
echo "Output dir: ${BLE_ANALYSIS_OUTPUT_DIR:-docs/ble-analysis}"
exit 0

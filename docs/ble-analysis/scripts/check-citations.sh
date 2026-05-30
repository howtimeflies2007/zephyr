#!/usr/bin/env bash
#
# scripts/check-citations.sh
#
# Verifies that every `file:line` citation in Zephyr BLE analysis
# artifacts points at a real line at the pinned analysis SHA.
#
# Catches three classes of error:
#   1. Hallucinated paths (file doesn't exist)
#   2. Hallucinated line numbers (line out of range)
#   3. SHA drift (citation was correct at write time, but the working
#      tree has since moved past the pinned SHA)
#
# Usage:
#   scripts/check-citations.sh                       # check all phases
#   scripts/check-citations.sh phase-1-hci           # check one phase
#   scripts/check-citations.sh --strict              # exit non-zero on any error
#   scripts/check-citations.sh --verbose             # print each citation checked
#   scripts/check-citations.sh --help
#
# Exits 0 on success (or no citations found).
# Exits 1 on usage error.
# Exits 2 if any citation failed validation AND --strict was set.
# In non-strict mode (default), always exits 0 — report only.
#
# Requires: bash 4+, git, grep, awk. No jq, no python.

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────

ANALYSIS_DIR="${BLE_ANALYSIS_OUTPUT_DIR:-docs/ble-analysis}"
ORIENTATION_FILE="$ANALYSIS_DIR/00-orientation.md"

# Defaults
STRICT=0
VERBOSE=0
TARGET_PHASE=""

# ─── Argument parsing ─────────────────────────────────────────────────────

usage() {
    # Print every '#' comment line from the top of the file until the
    # first non-comment line. Strips the leading '# ' on each.
    awk '/^#!/ {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)   STRICT=1; shift ;;
        --verbose)  VERBOSE=1; shift ;;
        -h|--help)  usage 0 ;;
        --*)        echo "Unknown option: $1" >&2; usage 1 ;;
        *)
            if [[ -n "$TARGET_PHASE" ]]; then
                echo "Multiple phases not supported. Got: $TARGET_PHASE and $1" >&2
                usage 1
            fi
            TARGET_PHASE="$1"
            shift
            ;;
    esac
done

# ─── Locate the repo root ─────────────────────────────────────────────────

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "ERROR: not inside a git repository" >&2
    exit 1
fi
cd "$REPO_ROOT"

# ─── Read the pinned SHA ──────────────────────────────────────────────────

if [[ ! -f "$ORIENTATION_FILE" ]]; then
    echo "ERROR: orientation file not found: $ORIENTATION_FILE" >&2
    echo "       Run Phase 0 Task 0.1 first to pin a SHA." >&2
    exit 1
fi

PINNED_SHA=$(grep -m1 -E '^Revision:[[:space:]]' "$ORIENTATION_FILE" \
             | awk '{print $2}' \
             | tr -d '[:space:]')

if [[ -z "$PINNED_SHA" ]]; then
    echo "ERROR: no 'Revision: <SHA>' line found in $ORIENTATION_FILE" >&2
    exit 1
fi

# Verify the pinned SHA exists locally
if ! git cat-file -e "$PINNED_SHA" 2>/dev/null; then
    echo "ERROR: pinned SHA $PINNED_SHA does not exist in local repo." >&2
    echo "       Run 'git fetch --all' or re-pin in 00-orientation.md." >&2
    exit 1
fi

HEAD_SHA=$(git rev-parse HEAD)
HEAD_MATCH_MARK=""
if [[ "$PINNED_SHA" != "$HEAD_SHA" ]]; then
    HEAD_MATCH_MARK=" (HEAD is $HEAD_SHA — checking against pinned)"
fi

# ─── Decide which artifacts to scan ───────────────────────────────────────

if [[ -n "$TARGET_PHASE" ]]; then
    SCAN_DIR="$ANALYSIS_DIR/$TARGET_PHASE"
    if [[ ! -d "$SCAN_DIR" ]]; then
        echo "ERROR: phase directory not found: $SCAN_DIR" >&2
        exit 1
    fi
else
    SCAN_DIR="$ANALYSIS_DIR"
fi

# ─── Counters ─────────────────────────────────────────────────────────────

TOTAL=0
OK=0
BAD_FILE=0
BAD_LINE=0
SKIPPED=0

declare -a FAILURES=()

# ─── Header ──────────────────────────────────────────────────────────────

echo "check-citations.sh"
echo "  Pinned SHA: $PINNED_SHA${HEAD_MATCH_MARK}"
echo "  Scanning:   $SCAN_DIR"
echo "  Mode:       $([ $STRICT -eq 1 ] && echo 'strict' || echo 'report-only')"
echo

# ─── Caches to avoid repeated git calls ──────────────────────────────────

declare -A FILE_LINE_COUNT_CACHE
declare -A FILE_EXISTS_CACHE

# Get the line count of a file at the pinned SHA. Cached.
# Returns -1 if file doesn't exist.
get_line_count() {
    local path="$1"
    if [[ -n "${FILE_LINE_COUNT_CACHE[$path]:-}" ]]; then
        echo "${FILE_LINE_COUNT_CACHE[$path]}"
        return
    fi
    local count
    if count=$(git -c core.quotePath=false show "$PINNED_SHA:$path" 2>/dev/null | wc -l); then
        FILE_LINE_COUNT_CACHE[$path]="$count"
        FILE_EXISTS_CACHE[$path]=1
        echo "$count"
    else
        FILE_LINE_COUNT_CACHE[$path]="-1"
        FILE_EXISTS_CACHE[$path]=0
        echo "-1"
    fi
}

# ─── Citation extraction ─────────────────────────────────────────────────

# A citation looks like one of:
#   subsys/bluetooth/host/hci_core.c:1247
#   `include/zephyr/bluetooth/hci_types.h:42`
#   - file.c:LLLL <function>  (in trace lists)
#
# Regex picks any token matching <path>:<digits> where path contains
# at least one '/' and ends with a known source extension or 'Kconfig*'.
# This excludes URLs (which have :// or no slash before colon) and
# common false positives like "Note: 1." or "Section 7.8.9".

CITATION_REGEX='([A-Za-z0-9_./-]+/[A-Za-z0-9_.+-]+\.(c|h|S|s|rst|cmake|yaml|yml|dts|dtsi|overlay|conf|py|sh)|Kconfig(\.[A-Za-z0-9_]+)?):([0-9]+)'

# Word-boundary version for grep -oE
CITATION_REGEX_GREP="(^|[[:space:]\`(\[<])${CITATION_REGEX}"

# ─── Scan ─────────────────────────────────────────────────────────────────

# Find every markdown and mermaid artifact under SCAN_DIR
mapfile -t ARTIFACTS < <(find "$SCAN_DIR" -type f \( -name '*.md' -o -name '*.mmd' \) | sort)

if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then
    echo "No .md or .mmd files found under $SCAN_DIR — nothing to check."
    exit 0
fi

for artifact in "${ARTIFACTS[@]}"; do
    # Skip the plan file itself and PLACEMENT — they describe the analysis,
    # they don't contain code citations meant to be validated against the SHA.
    case "$artifact" in
        */plans/*)        SKIPPED=$((SKIPPED+1)); continue ;;
        */PLACEMENT.md)   SKIPPED=$((SKIPPED+1)); continue ;;
        */README.md)      SKIPPED=$((SKIPPED+1)); continue ;;
    esac

    # Extract citations. Use -oE to print only the match, then strip the
    # leading boundary character.
    mapfile -t CITES < <(
        grep -oE "$CITATION_REGEX_GREP" "$artifact" 2>/dev/null \
        | sed -E 's/^[[:space:]\`(<\[]+//' \
        | sort -u
    )

    [[ ${#CITES[@]} -eq 0 ]] && continue

    if [[ $VERBOSE -eq 1 ]]; then
        echo "─── $artifact (${#CITES[@]} unique citations) ───"
    fi

    for cite in "${CITES[@]}"; do
        TOTAL=$((TOTAL+1))

        path="${cite%:*}"
        line="${cite##*:}"

        # Sanity check line number is purely digits
        if ! [[ "$line" =~ ^[0-9]+$ ]]; then
            continue
        fi

        line_count=$(get_line_count "$path")

        if [[ "$line_count" == "-1" ]]; then
            BAD_FILE=$((BAD_FILE+1))
            FAILURES+=("[NO-FILE]  $artifact :: $cite")
            [[ $VERBOSE -eq 1 ]] && echo "  ✗ NO FILE   $cite"
        elif (( line > line_count )); then
            BAD_LINE=$((BAD_LINE+1))
            FAILURES+=("[OUT-OF-RANGE]  $artifact :: $cite (file has $line_count lines)")
            [[ $VERBOSE -eq 1 ]] && echo "  ✗ OUT-OF-RANGE  $cite (file has $line_count lines)"
        else
            OK=$((OK+1))
            [[ $VERBOSE -eq 1 ]] && echo "  ✓ $cite"
        fi
    done
done

# ─── Report ───────────────────────────────────────────────────────────────

echo
echo "═══════════════════════════════════════════════════════"
echo "  Citations checked: $TOTAL"
echo "  ✓ Valid:           $OK"
echo "  ✗ No such file:    $BAD_FILE"
echo "  ✗ Line out of range: $BAD_LINE"
echo "  Artifacts skipped: $SKIPPED (plans, READMEs, PLACEMENT)"
echo "═══════════════════════════════════════════════════════"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo
    echo "FAILURES:"
    for f in "${FAILURES[@]}"; do
        echo "  $f"
    done

    if [[ $STRICT -eq 1 ]]; then
        echo
        echo "Exiting non-zero due to --strict mode."
        exit 2
    fi
fi

exit 0

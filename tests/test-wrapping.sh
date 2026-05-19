#!/bin/bash
# test-wrapping.sh — QA tool: compile swarmwrap test files with LuaLaTeX and analyze
#
# Usage:
#   ./tests/test-wrapping.sh                          # test all default files
#   ./tests/test-wrapping.sh test-customwrap.tex      # test one file
#   ./tests/test-wrapping.sh --verbose test-customwrap.tex
#
# This script:
#   1. ALWAYS compiles with LuaLaTeX (never pdfLaTeX)
#   2. Verifies the engine is LuaHBTeX (not pdfTeX) from the .log file
#   3. Calls analyze-wrapping.py on the resulting PDF
#   4. Reports: "overlap found", "wrongful whitespace found", or "no problem found"
#
# Exit codes:
#   0 — no problem found (clean)
#   1 — overlap or whitespace issues detected
#   2 — compilation error or wrong engine

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEXLIVE="$PROJECT_DIR/texlive/bin/x86_64-linux"
TEST_DIR="$PROJECT_DIR/src/test-wrapfig"
THEME_DIR="$PROJECT_DIR/src/themes"

LUALATEX="$TEXLIVE/lualatex"
ANALYZE="$SCRIPT_DIR/analyze-wrapping.py"

VERBOSE=false

# Default test files
DEFAULT_TESTS=(
    "test-customwrap.tex"
    "test-pagebreak-variations.tex"
)

# ── Functions ────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 [--verbose] [test-file.tex ...]"
    echo ""
    echo "Compile swarmwrap test files with LuaLaTeX and analyze for overlaps."
    echo ""
    echo "Options:"
    echo "  --verbose    Show per-page analysis details"
    echo "  --help       Show this help"
    echo ""
    echo "If no test files are specified, tests all of:"
    for t in "${DEFAULT_TESTS[@]}"; do
        echo "  $t"
    done
    echo ""
    echo "Exit codes:"
    echo "  0  No problems found"
    echo "  1  Overlap or whitespace issues detected"
    echo "  2  Compilation error or wrong engine detected"
}

log() {
    echo "[test-wrapping] $*"
}

die() {
    echo "[test-wrapping] ERROR: $*" >&2
    exit 2
}

# ── Parse Arguments ──────────────────────────────────────────────────────────

TESTS=()

for arg in "$@"; do
    case "$arg" in
        --verbose)
            VERBOSE=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            TESTS+=("$arg")
            ;;
    esac
done

if [ ${#TESTS[@]} -eq 0 ]; then
    TESTS=("${DEFAULT_TESTS[@]}")
fi

# ── Pre-flight Checks ────────────────────────────────────────────────────────

# Check TeX Live
if [ ! -x "$LUALATEX" ]; then
    die "LuaLaTeX not found at $LUALATEX. Run setup.sh first."
fi

# Check Python / PyMuPDF
if ! python3 -c "import fitz" 2>/dev/null; then
    die "PyMuPDF not installed. Run: pip3 install --break-system-packages pymupdf"
fi

# Check analyze script
if [ ! -f "$ANALYZE" ]; then
    die "analyze-wrapping.py not found at $ANALYZE"
fi

# ── Main Loop ────────────────────────────────────────────────────────────────

OVERALL_EXIT=0

for testfile in "${TESTS[@]}"; do
    # Resolve path: if relative, look in TEST_DIR
    if [[ "$testfile" != /* ]] && [[ "$testfile" != */* ]]; then
        texpath="$TEST_DIR/$testfile"
    elif [[ "$testfile" != /* ]]; then
        texpath="$PWD/$testfile"
    else
        texpath="$testfile"
    fi

    if [ ! -f "$texpath" ]; then
        die "Test file not found: $texpath"
    fi

    basename_test="$(basename "$texpath")"
    pdfpath="${texpath%.tex}.pdf"
    logpath="${texpath%.tex}.log"

    log "Compiling $basename_test with LuaLaTeX..."

    # Compile with LuaLaTeX, 2 passes (for references)
    TEXINPUTS=".:$THEME_DIR:" "$LUALATEX" \
        --interaction=nonstopmode \
        --output-directory="$(dirname "$texpath")" \
        "$texpath" > /dev/null 2>&1

    if [ ! -f "$pdfpath" ]; then
        die "Compilation failed: $pdfpath not produced. Check $logpath"
    fi

    # CRITICAL: Verify the engine is LuaHBTeX, not pdfTeX
    if [ -f "$logpath" ]; then
        engine=$(head -3 "$logpath" | grep -o 'LuaHBTeX\|pdfTeX\|XeTeX' | head -1)
        if [ "$engine" != "LuaHBTeX" ]; then
            die "Wrong engine detected: $engine (expected LuaHBTeX). Check TEXINPUTS."
        fi
        log "Engine verified: $engine"
    fi

    # Check for ! errors in the log
    if [ -f "$logpath" ]; then
        errors=$(grep -c '^!' "$logpath" 2>/dev/null || true)
        errors=${errors:-0}
        if [ "$errors" -gt 0 ]; then
            log "WARNING: $errors compilation error(s) in $basename_test"
        fi
    fi

    log "Analyzing $basename_test..."

    # Run analysis
    analyze_args=("$ANALYZE" "$pdfpath")
    if $VERBOSE; then
        analyze_args+=("--verbose")
    fi

    result=$(python3 "${analyze_args[@]}" 2>&1) || true

    echo ""
    echo "=== $basename_test ==="
    echo "$result"
    echo ""

    # Check exit code
    if echo "$result" | grep -q "overlap found\|wrongful whitespace found"; then
        OVERALL_EXIT=1
    fi
done

if [ "$OVERALL_EXIT" -eq 0 ]; then
    log "All tests passed — no problems found."
else
    log "Issues detected — see above."
fi

exit $OVERALL_EXIT

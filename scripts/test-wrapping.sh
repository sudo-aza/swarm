#!/usr/bin/env bash
# test-wrapping.sh — Compile swarmwrap test .tex with LuaLaTeX and analyze the PDF
#
# Usage:
#   bash scripts/test-wrapping.sh <test-file.tex> [test-file2.tex ...]
#   bash scripts/test-wrapping.sh --all    # runs against all swarmwrap test files
#
# What it does:
#   1. ALWAYS compiles with LuaLaTeX (never pdfLaTeX — that's the whole point)
#   2. Verifies the log shows LuaHBTeX (not pdfTeX)
#   3. Calls analyze-wrapping.py on the resulting PDF
#   4. Prints overlap / whitespace / ghost-narrowing results
#
# Exit codes:
#   0 = no issues found (but still review manually)
#   1 = overlap detected
#   2 = whitespace detected
#   3 = ghost narrowing detected
#   4 = multiple issues
#   10 = compilation failed
#   11 = wrong engine (pdfTeX instead of LuaHBTeX)
#   99 = script error

set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEXLIVE="$PROJECT_DIR/texlive/bin/x86_64-linux"
ANALYZE="$SCRIPT_DIR/analyze-wrapping.py"
TEST_DIR="$PROJECT_DIR/src/test-wrapfig"
THEMES_DIR="$PROJECT_DIR/src/themes"

LUALATEX="$TEXLIVE/lualatex"

if [ ! -x "$LUALATEX" ]; then
    echo "ERROR: LuaLaTeX not found at $LUALATEX" >&2
    exit 99
fi

if [ ! -f "$ANALYZE" ]; then
    echo "ERROR: analyze-wrapping.py not found at $ANALYZE" >&2
    exit 99
fi

export PATH="$TEXLIVE:$PATH"
export TEXINPUTS=".:$THEMES_DIR:"

# --- Functions ---

compile_and_analyze() {
    local tex_file="$1"
    local base_name
    base_name="$(basename "$tex_file" .tex)"
    local dir_name
    dir_name="$(dirname "$tex_file")"
    local pdf_file="$dir_name/$base_name.pdf"
    local log_file="$dir_name/$base_name.log"

    echo "=========================================="
    echo "TEST: $base_name"
    echo "=========================================="
    echo ""

    # Step 1: Compile with LuaLaTeX
    echo "[1/3] Compiling with LuaLaTeX..."
    cd "$dir_name"

    if ! TEXINPUTS=".:$THEMES_DIR:" "$LUALATEX" --interaction=nonstopmode --halt-on-error "$tex_file" > /dev/null 2>&1; then
        echo "  COMPILE FAILED — attempting with --interaction=scrollmode for error details"
        if ! TEXINPUTS=".:$THEMES_DIR:" "$LUALATEX" --interaction=scrollmode "$tex_file" 2>&1 | tail -20; then
            echo "  ERROR: Compilation failed. Check $log_file"
            return 10
        fi
    fi

    cd "$PROJECT_DIR"

    # Step 2: Verify engine is LuaHBTeX
    echo "[2/3] Verifying engine..."
    if [ ! -f "$log_file" ]; then
        echo "  ERROR: Log file not found: $log_file"
        return 10
    fi

    local engine
    engine="$(head -3 "$log_file" | grep -o 'LuaHBTeX\|LuaLaTeX\|pdfTeX\|XeTeX' | head -1 || echo 'UNKNOWN')"

    if [[ "$engine" == "pdfTeX" ]]; then
        echo "  ERROR: Compiled with pdfTeX instead of LuaHBTeX! swarmwrap requires LuaLaTeX."
        echo "  This means swarmwrap silently fell back to plain floats — no wrapping happened."
        echo "  FIX: Ensure LuaLaTeX is used: TEXINPUTS=... lualatex $tex_file"
        return 11
    fi

    echo "  Engine: $engine ✓"

    if [ ! -f "$pdf_file" ]; then
        echo "  ERROR: PDF not found: $pdf_file"
        return 10
    fi

    local page_count
    page_count="$(python3 -c "import fitz; print(len(fitz.open('$pdf_file')))" 2>/dev/null || echo '?')"
    echo "  Pages: $page_count"

    # Check for errors in log
    local errors
    errors="$(grep -c '^!' "$log_file" 2>/dev/null || echo 0)"
    echo "  Errors (!): $errors"

    local overfull
    overfull="$(grep -c 'Overfull' "$log_file" 2>/dev/null || echo 0)"
    echo "  Overfull: $overfull"

    echo ""

    # Step 3: Analyze PDF
    echo "[3/3] Analyzing PDF for overlap/whitespace/narrowing..."
    echo ""

    python3 "$ANALYZE" "$pdf_file" \
        --whitespace-threshold 36.0 \
        --overlap-tolerance 2.0 \
        --ghost-threshold 20.0 \
        || true

    echo ""
    return 0
}

# --- Main ---

if [ $# -eq 0 ]; then
    echo "Usage: bash scripts/test-wrapping.sh <test-file.tex> [test-file2.tex ...]"
    echo "       bash scripts/test-wrapping.sh --all"
    exit 1
fi

if [ "$1" == "--all" ]; then
    echo "Running all swarmwrap test files..."
    echo ""
    files=(
        "$TEST_DIR/test-customwrap.tex"
        "$TEST_DIR/test-pagebreak-variations.tex"
    )
    exit_codes=()
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            compile_and_analyze "$f" && exit_codes+=($?) || exit_codes+=($?)
        else
            echo "SKIP: $f not found"
        fi
    done

    echo "=========================================="
    echo "SUMMARY"
    echo "=========================================="
    for i in "${!files[@]}"; do
        echo "  $(basename "${files[$i]}"): exit code ${exit_codes[$i]}"
    done

    # Return worst exit code
    worst=0
    for c in "${exit_codes[@]}"; do
        if [ "$c" -gt "$worst" ] 2>/dev/null; then
            worst="$c"
        fi
    done
    exit "$worst"
else
    exit_code=0
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            echo "ERROR: File not found: $f" >&2
            exit_code=99
            continue
        fi
        compile_and_analyze "$f" && true || exit_code=$?
    done
    exit "$exit_code"
fi

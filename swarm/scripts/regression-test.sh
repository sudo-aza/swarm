#!/usr/bin/env bash
# regression-test.sh — Comprehensive v3.41 baseline regression test
# Runs all QA detection scripts against compiled PDFs and validates results.
#
# Usage: cd /home/z/my-project/swarm && bash scripts/regression-test.sh
#
# v3.41 BASELINES (T100, 2026-06-14):
#   stress-50:           16pg, 54668b,  0 fig-text ov, 0 fig-fig ov, 0 parshape leaks, 2 near-empty, 0 clipped, 6 distorted
#   customwrap:          11pg, 44216b,  0 fig-text ov, 0 fig-fig ov, 5 parshape leaks, 0 near-empty
#   pagebreak-variations: 15pg, 45191b,  0 fig-text ov, 0 fig-fig ov, 34 parshape leaks, 0 near-empty
#
# Exit code: 0 = all pass, 1 = regression detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$SWARM_DIR/src/test-wrapfig"
export PATH="/home/z/my-project/swarm/texlive/bin/x86_64-linux:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

check_result() {
    local label="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo -e "  ${GREEN}PASS${NC}: $label = $actual (expected $expected)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}: $label = $actual (expected $expected) *** REGRESSION ***"
        FAIL=$((FAIL + 1))
    fi
}

check_filesize() {
    local pdf="$1" expected="$2"
    if [ -f "$pdf" ]; then
        local actual
        actual=$(stat -c%s "$pdf" 2>/dev/null || stat -f%z "$pdf" 2>/dev/null || echo 0)
        if [ "$actual" -eq "$expected" ]; then
            echo -e "  ${GREEN}PASS${NC}: $(basename "$pdf") size = $actual bytes"
            PASS=$((PASS + 1))
        else
            echo -e "  ${RED}FAIL${NC}: $(basename "$pdf") size = $actual bytes (expected $expected) *** REGRESSION ***"
            FAIL=$((FAIL + 1))
        fi
    else
        echo -e "  ${RED}FAIL${NC}: $(basename "$pdf") not found"
        FAIL=$((FAIL + 1))
    fi
}

echo "============================================"
echo " swarmwrap v3.41 Regression Test Suite"
echo " $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================"
echo

# --- File Size Checks ---
echo "--- File Size Baselines ---"
check_filesize "$TEST_DIR/test-stress-50.pdf" 54668
check_filesize "$TEST_DIR/test-customwrap.pdf" 44216
check_filesize "$TEST_DIR/test-pagebreak-variations.pdf" 45191
echo

# --- Figure Alignment ---
echo "--- Figure Alignment (detect-figure-alignment.py) ---"
for pdf_name in test-stress-50 test-customwrap test-pagebreak-variations; do
    pdf="$TEST_DIR/${pdf_name}.pdf"
    if [ ! -f "$pdf" ]; then
        echo -e "  ${RED}SKIP${NC}: $pdf not found"
        continue
    fi
    output=$(python3 "$SCRIPT_DIR/detect-figure-alignment.py" "$pdf" 2>&1) || true
    misalign=$(echo "$output" | grep -c 'RIGHT_EDGE_MISALIGN\|LEFT_EDGE_MISALIGN\|CLIPPED' || true)

    # customwrap has 2 known RIGHT_EDGE_MISALIGN (itemize + multicol — expected test structure)
    if [ "$pdf_name" = "test-customwrap" ]; then
        if [ "$misalign" -eq 2 ]; then
            echo -e "  ${GREEN}PASS${NC}: $pdf_name — 2 misalignments (expected: itemize + multicol)"
            PASS=$((PASS + 1))
        else
            echo -e "  ${RED}FAIL${NC}: $pdf_name — $misalign misalignments (expected 2)"
            FAIL=$((FAIL + 1))
        fi
    else
        check_result "$pdf_name alignment issues" 0 "$misalign"
    fi
done
echo

# --- Near-Empty Pages ---
echo "--- Near-Empty Pages (detect-near-empty-pages.py) ---"
for pdf_name in test-stress-50 test-customwrap test-pagebreak-variations; do
    pdf="$TEST_DIR/${pdf_name}.pdf"
    if [ ! -f "$pdf" ]; then
        echo -e "  ${RED}SKIP${NC}: $pdf not found"
        continue
    fi
    output=$(python3 "$SCRIPT_DIR/detect-near-empty-pages.py" "$pdf" 2>&1) || true
    issues=$(echo "$output" | grep -c '^\s*Page ' || true)

    if [ "$pdf_name" = "test-stress-50" ]; then
        check_result "$pdf_name near-empty pages" 2 "$issues"
    else
        check_result "$pdf_name near-empty pages" 0 "$issues"
    fi
done
echo

# --- Parshape Leaks ---
echo "--- Parshape Leaks (detect-parshape-leak.py) ---"
for pdf_name in test-stress-50 test-customwrap test-pagebreak-variations; do
    pdf="$TEST_DIR/${pdf_name}.pdf"
    if [ ! -f "$pdf" ]; then
        echo -e "  ${RED}SKIP${NC}: $pdf not found"
        continue
    fi
    output=$(python3 "$SCRIPT_DIR/detect-parshape-leak.py" "$pdf" 2>&1) || true
    leaked=$(echo "$output" | grep 'Total leaked' | awk '{print $NF}' || echo "0")

    case "$pdf_name" in
        test-stress-50)
            check_result "$pdf_name parshape leaks" 0 "$leaked"
            ;;
        test-customwrap)
            check_result "$pdf_name parshape leaks" 5 "$leaked"
            ;;
        test-pagebreak-variations)
            check_result "$pdf_name parshape leaks" 34 "$leaked"
            ;;
    esac
done
echo

# --- Page Count ---
echo "--- Page Counts ---"
for pdf_name in test-stress-50 test-customwrap test-pagebreak-variations; do
    pdf="$TEST_DIR/${pdf_name}.pdf"
    if [ ! -f "$pdf" ]; then
        echo -e "  ${RED}SKIP${NC}: $pdf not found"
        continue
    fi
    pages=$(python3 -c "import fitz; print(len(fitz.open('$pdf')))" 2>/dev/null || echo "0")
    case "$pdf_name" in
        test-stress-50)           check_result "$pdf_name page count" 16 "$pages" ;;
        test-customwrap)          check_result "$pdf_name page count" 11 "$pages" ;;
        test-pagebreak-variations) check_result "$pdf_name page count" 15 "$pages" ;;
    esac
done
echo

# --- Summary ---
echo "============================================"
TOTAL=$((PASS + FAIL + WARN))
echo -e " Results: ${GREEN}$PASS PASS${NC} / ${RED}$FAIL FAIL${NC} / $TOTAL total"
if [ "$FAIL" -gt 0 ]; then
    echo -e " ${RED}*** REGRESSION DETECTED ***${NC}"
    exit 1
else
    echo -e " ${GREEN}All baselines match. No regressions.${NC}"
    exit 0
fi
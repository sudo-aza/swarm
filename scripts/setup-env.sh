#!/usr/bin/env bash
# =============================================================================
# setup-env.sh — DEPRECATED: use setup.sh instead
#
# This script has been merged into setup.sh.  The consolidated script handles:
#   - System dependencies (with optional sudo)
#   - TeX Live portable install (flat path: texlive/bin/<arch>/)
#   - Python virtual environment
#   - Shell aliases
#
# Usage:
#   ./scripts/setup.sh
#   ./scripts/setup.sh --skip-system    # skip apt-get
#   ./scripts/setup.sh --skip-texlive   # skip TeX Live
# =============================================================================

echo "setup-env.sh is deprecated. Use setup.sh instead:"
echo "  ./scripts/setup.sh"
echo ""
echo "Flags:"
echo "  --skip-system    Skip system package installation"
echo "  --skip-texlive   Skip TeX Live installation"
echo "  --help           Show all options"
echo ""

# Forward to the real script
exec "$(dirname "$0")/setup.sh" "$@"

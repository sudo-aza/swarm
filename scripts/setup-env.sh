#!/bin/bash
# ============================================================
# LaTeX Environment Setup Script for the Swarm Project
# Installs a portable TeX Live distribution + Python + tools
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEXLIVE_DIR="$PROJECT_DIR/texlive"
INSTALLER_DIR="$PROJECT_DIR/.install-tl-cache"

# --- Color helpers ---
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# --- Detect platform ---
detect_platform() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  PLATFORM="x86_64-linux" ;;
        aarch64) PLATFORM="aarch64-linux" ;;
        arm64)   PLATFORM="aarch64-linux" ;;
        *)       err "Unsupported architecture: $arch"; exit 1 ;;
    esac
    ok "Detected platform: $PLATFORM"
}

# --- Install portable TeX Live ---
install_texlive() {
    if [ -x "$TEXLIVE_DIR/2025/bin/$PLATFORM/lualatex" ]; then
        ok "TeX Live already installed, skipping."
        return 0
    fi

    info "Downloading TeX Live net installer..."
    mkdir -p "$INSTALLER_DIR"
    cd "$INSTALLER_DIR"

    if [ ! -f "install-tl-unx.tar.gz" ]; then
        wget -q --show-progress "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz" \
            -O install-tl-unx.tar.gz
    fi

    tar -xzf install-tl-unx.tar.gz
    cd install-tl-*/

    info "Installing TeX Live (scheme-full, portable)..."
    info "This may take a while (8-10 GB download)..."

    TEXLIVE_INSTALL_PREFIX="$TEXLIVE_DIR" \
    TEXLIVE_INSTALL_DIR="$TEXLIVE_DIR/2025" \
    ./install-tl \
        --scheme=full \
        --portable \
        --no-interaction \
        --texdir="$TEXLIVE_DIR/2025" \
        --binary="$PLATFORM" \
        --texdir="$TEXLIVE_DIR/2025" \
        --instopt_relative \
        --path_relative \
        --logfile="$INSTALLER_DIR/install.log"

    cd "$PROJECT_DIR"
    ok "TeX Live installed successfully."
}

# --- Create env setup script ---
create_env_script() {
    cat > "$TEXLIVE_DIR/setup-env.sh" << ENVEOF
#!/bin/bash
# Source this file to add TeX Live to your PATH
TLDIR="\$(cd "\$(dirname "\$0")" && pwd)/2025"
export PATH="\$TLDIR/bin/$PLATFORM:\$PATH"
export INFOPATH="\$TLDIR/texmf-dist/doc/info\${INFOPATH:+:\$INFOPATH}"
export MANPATH="\$TLDIR/texmf-dist/doc/man\${MANPATH:+:\$MANPATH}"
echo "TeX Live environment activated (from \$TLDIR)"
echo "  lualatex: \$(which lualatex 2>/dev/null || echo 'not found')"
echo "  pdflatex: \$(which pdflatex 2>/dev/null || echo 'not found')"
ENVEOF
    chmod +x "$TEXLIVE_DIR/setup-env.sh"
    ok "Created $TEXLIVE_DIR/setup-env.sh"
}

# --- Install Python + Pygments (for minted) ---
install_python_deps() {
    if command -v python3 &>/dev/null && python3 -c "import pygments" 2>/dev/null; then
        ok "Python + Pygments already available."
        return 0
    fi

    info "Installing Python dependencies..."
    if command -v python3 &>/dev/null; then
        python3 -m pip install --quiet Pygments
    elif command -v pip3 &>/dev/null; then
        pip3 install --quiet Pygments
    else
        warn "Python not found. Install python3 + pip for minted support."
        warn "  apt: sudo apt install python3 python3-pip"
        return 1
    fi
    ok "Pygments installed."
}

# --- Install system tools ---
install_system_tools() {
    info "Checking/installing system tools..."
    local missing=()
    for cmd in git wget stat; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing system tools: ${missing[*]}"
        warn "  apt: sudo apt install ${missing[*]}"
    else
        ok "All system tools available."
    fi
}

# --- Create gitignore ---
create_gitignore() {
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# TeX Live
texlive/
.install-tl-cache/

# LaTeX build artifacts
*.aux
*.log
*.out
*.toc
*.lof
*.lot
*.fls
*.fdb_latexmk
*.synctex.gz
*.bbl
*.blg
*.bcf
*.run.xml
*.pdf
*.dvi
*.ps
*.eps
_minted-*/
__pycache__/
*.pyc
EOF
    ok "Created .gitignore"
}

# --- Main ---
main() {
    echo "=========================================="
    echo "  Swarm LaTeX Environment Setup"
    echo "=========================================="
    echo ""

    detect_platform
    install_system_tools
    install_texlive
    create_env_script
    install_python_deps
    create_gitignore

    echo ""
    echo "=========================================="
    echo "  Setup complete!"
    echo "=========================================="
    echo ""
    echo "  To activate TeX Live, run:"
    echo "    source $TEXLIVE_DIR/setup-env.sh"
    echo ""
    echo "  Or add to your shell profile:"
    echo "    echo 'source $TEXLIVE_DIR/setup-env.sh' >> ~/.bashrc"
    echo ""
}

main "$@"

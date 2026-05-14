#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-shot environment installer for the LaTeX Helper Swarm project
#
# Consolidates the old setup.sh + setup-env.sh into a single script.
# Re-runnable on a fresh VM — skips steps that are already done.
#
# Installs:
#   - System dependencies (optional sudo, with fallback)
#   - TeX Live (portable, full scheme) into ./texlive/
#   - Python 3 virtual environment with required pip packages
#   - Convenience aliases in ~/.bashrc
#
# Usage:
#   chmod +x scripts/setup.sh && ./scripts/setup.sh
#   ./scripts/setup.sh --skip-system    # skip apt-get, just do TeX + Python
#   ./scripts/setup.sh --skip-texlive   # skip TeX Live install
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEXLIVE_DIR="${REPO_ROOT}/texlive"
INSTALLER_CACHE="${REPO_ROOT}/.install-tl-cache"
TEXLIVE_INSTALLER_URL="https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"

# ── Color helpers ────────────────────────────────────────────────────────────
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# ── Parse flags ──────────────────────────────────────────────────────────────
SKIP_SYSTEM=false
SKIP_TEXLIVE=false

for arg in "$@"; do
    case "$arg" in
        --skip-system)   SKIP_SYSTEM=true ;;
        --skip-texlive)  SKIP_TEXLIVE=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-system] [--skip-texlive]"
            echo ""
            echo "  --skip-system    Skip system package installation (apt-get)"
            echo "  --skip-texlive   Skip TeX Live installation"
            echo "  --help           Show this help"
            exit 0
            ;;
        *)
            warn "Unknown argument: $arg"
            ;;
    esac
done

echo "============================================"
echo "  LaTeX Helper Swarm — Environment Setup"
echo "  Date: $(date -Iseconds)"
echo "  Repo: ${REPO_ROOT}"
echo "============================================"
echo ""

# ── Detect platform ─────────────────────────────────────────────────────────
detect_platform() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  PLATFORM="x86_64-linux" ;;
        aarch64) PLATFORM="aarch64-linux" ;;
        arm64)   PLATFORM="aarch64-linux" ;;
        *)       err "Unsupported architecture: $arch"; exit 1 ;;
    esac
    ok "Detected platform: ${PLATFORM}"
}

# ── System dependencies ─────────────────────────────────────────────────────
install_system_deps() {
    if [ "${SKIP_SYSTEM}" = true ]; then
        info "Skipping system packages (--skip-system)."
        return 0
    fi

    info "Installing system packages..."

    # Check if sudo is available; fall back to running without it if not
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        warn "sudo not available — attempting install without it."
        warn "If this fails, install packages manually:"
        warn "  apt-get install git git-lfs python3 python3-pip python3-venv"
        warn "    curl wget perl build-essential fonts-noto-cjk fonts-noto"
        warn "    fonts-liberation inotify-tools zip unzip tar"
        SUDO=""
    fi

    # shellcheck disable=SC2086
    ${SUDO} apt-get update -qq
    # shellcheck disable=SC2086
    ${SUDO} apt-get install -y -qq \
        git git-lfs \
        python3 python3-pip python3-venv \
        curl wget perl \
        build-essential \
        fonts-noto-cjk fonts-noto fonts-liberation \
        inotify-tools \
        zip unzip tar \
        > /dev/null 2>&1

    ok "System packages installed."
}

# ── TeX Live (portable install) ─────────────────────────────────────────────
install_texlive() {
    if [ "${SKIP_TEXLIVE}" = true ]; then
        info "Skipping TeX Live install (--skip-texlive)."
        return 0
    fi

    local texbin="${TEXLIVE_DIR}/bin/${PLATFORM}"

    if [ -x "${texbin}/lualatex" ]; then
        ok "TeX Live already installed at ${TEXLIVE_DIR}. Updating..."
        "${texbin}/tlmgr" update --self --all --quiet 2>/dev/null || true
        return 0
    fi

    info "Installing TeX Live (scheme-full, portable)..."
    info "This may take a while (~8-10 GB download)..."

    mkdir -p "${TEXLIVE_DIR}" "${INSTALLER_CACHE}"
    cd "${INSTALLER_CACHE}"

    # Download installer if not cached
    if [ ! -f "install-tl-unx.tar.gz" ]; then
        info "Downloading TeX Live installer..."
        curl -sL "${TEXLIVE_INSTALLER_URL}" -o install-tl-unx.tar.gz
    fi

    # Extract and run installer
    tar -xzf install-tl-unx.tar.gz
    cd install-tl-*/

    # Use --binary for correct architecture on non-x86_64 systems.
    # Install directly into texlive/ (flat, no year subdirectory) so that
    # compile.py can find texlive/bin/<arch>/ without guessing the year.
    ./install-tl \
        --scheme=full \
        --portable \
        --installdir="${TEXLIVE_DIR}" \
        --texdir="${TEXLIVE_DIR}" \
        --texmflocal="${TEXLIVE_DIR}/texmf-local" \
        --binary="${PLATFORM}" \
        --no-interaction \
        --logfile="${INSTALLER_CACHE}/install.log" \
        2>&1

    cd "${REPO_ROOT}"
    ok "TeX Live installed."

    # Install commonly-needed extra packages
    info "Installing extra TeX packages..."
    "${texbin}/tlmgr" install \
        collection-fontsrecommended \
        collection-latexextra \
        collection-luatex \
        collection-bibtexextra \
        collection-pictures \
        collection-publisher \
        minted \
        pygments \
        tcolorbox \
        fontawesome5 \
        babel \
        microtype \
        hyperref \
        booktabs \
        tabularx \
        longtable \
        geometry \
        xcolor \
        graphicx \
        enumitem \
        caption \
        subcaption \
        float \
        placeins \
        ntheorem \
        amsmath amssymb amsthm \
        algorithm2e \
        listings \
        pgfplots \
        tikz \
        2>/dev/null || true

    ok "TeX Live ready at ${TEXLIVE_DIR}"
}

# ── Python virtual environment ──────────────────────────────────────────────
install_python_venv() {
    info "Setting up Python venv..."

    if [ ! -d "${REPO_ROOT}/.venv" ]; then
        python3 -m venv "${REPO_ROOT}/.venv"
    fi

    # shellcheck disable=SC1091
    source "${REPO_ROOT}/.venv/bin/activate"

    pip install --upgrade pip --quiet
    pip install --quiet \
        pyyaml \
        chardet \
        pillow \
        matplotlib \
        jinja2 \
        watchdog \
        click \
        rich \
        pymupdf \
        2>/dev/null || true

    # Pygments is needed for minted code highlighting
    if ! python3 -c "import pygments" 2>/dev/null; then
        pip install --quiet Pygments
    fi

    ok "Python venv ready at ${REPO_ROOT}/.venv"
}

# ── PATH & aliases ──────────────────────────────────────────────────────────
configure_shell() {
    info "Configuring PATH and aliases..."

    local bashrc="${HOME}/.bashrc"
    local marker="# >>> LaTeX Helper Swarm >>>"

    # Remove old block if present (idempotent)
    if grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        sed -i "/${marker}/,/# <<< LaTeX Helper Swarm <<</d" "${bashrc}"
    fi

    cat >> "${bashrc}" <<EOF

${marker}
# LaTeX Helper Swarm environment
export SWARM_REPO="${REPO_ROOT}"
export PATH="${TEXLIVE_DIR}/bin/${PLATFORM}:\${PATH}"
export INFOPATH="${TEXLIVE_DIR}/texmf-dist/doc/info\${INFOPATH:+:\${INFOPATH}}"
export MANPATH="${TEXLIVE_DIR}/texmf-dist/doc/man\${MANPATH:+:\${MANPATH}}"
alias sw-cd="cd ${REPO_ROOT}"
alias sw-latex="pdflatex -interaction=nonstopmode -file-line-error"
alias sw-lualatex="lualatex -interaction=nonstopmode -file-line-error"
alias sw-xelatex="xelatex -interaction=nonstopmode -file-line-error"
alias sw-bib="bibtex"
alias sw-biber="biber"
alias sw-clean="find . -name '*.aux' -o -name '*.log' -o -name '*.toc' -o -name '*.out' -o -name '*.fls' -o -name '*.fdb_latexmk' -o -name '*.synctex.gz' | xargs rm -f"
alias sw-venv="source ${REPO_ROOT}/.venv/bin/activate"
alias sw-pull='cd ${REPO_ROOT} && git pull origin main'
alias sw-push='cd ${REPO_ROOT} && git add -A && git commit -m "auto: $(date +%Y-%m-%d\ %H:%M)" && git push origin main'
alias sw-compile='cd ${REPO_ROOT} && python3 scripts/compile.py'
# <<< LaTeX Helper Swarm <<<
EOF

    ok "Aliases added to ~/.bashrc"
}

# ── Git LFS ──────────────────────────────────────────────────────────────────
init_git_lfs() {
    cd "${REPO_ROOT}"
    git lfs install 2>/dev/null || true
}

# ── Summary ─────────────────────────────────────────────────────────────────
print_summary() {
    local texbin="${TEXLIVE_DIR}/bin/${PLATFORM}"
    echo ""
    echo "============================================"
    echo "  Setup complete!"
    echo ""
    echo "  Next steps:"
    echo "    source ~/.bashrc        # reload shell"
    echo "    sw-venv                 # activate Python venv"
    echo "    sw-compile demo.tex     # compile a document"
    echo "    sw-pull                 # git pull"
    echo ""
    echo "  TeX Live:  ${texbin}"
    echo "  Python:    ${REPO_ROOT}/.venv/bin/python3"
    echo "  Repo:      ${REPO_ROOT}"
    echo "============================================"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    detect_platform
    install_system_deps
    install_texlive
    install_python_venv
    configure_shell
    init_git_lfs
    print_summary
}

main "$@"

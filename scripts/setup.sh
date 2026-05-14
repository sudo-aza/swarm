#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-shot environment installer for the LaTeX Helper Swarm project
#
# Designed to be re-runnable on a fresh VM. Installs:
#   - TeX Live (portable, full scheme) into ./texlive/
#   - Python 3 + pip packages needed by helper scripts
#   - Git LFS (for large binary assets if needed)
#   - Adds convenience aliases to ~/.bashrc
#
# Usage:
#   chmod +x scripts/setup.sh && ./scripts/setup.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEXLIVE_DIR="${REPO_ROOT}/texlive"
TEXLIVE_VERSION="2024"
TEXLIVE_INSTALLER_URL="https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"

echo "============================================"
echo "  LaTeX Helper Swarm — Environment Setup"
echo "  Date: $(date -Iseconds)"
echo "  Repo: ${REPO_ROOT}"
echo "============================================"

# ── System dependencies ──────────────────────────────────────────────────────
echo "[1/4] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    git git-lfs \
    python3 python3-pip python3-venv \
    curl wget perl \
    build-essential \
    fonts-noto-cjk fonts-noto fonts-liberation \
    inotify-tools \
    zip unzip tar \
    > /dev/null 2>&1

echo "  System packages installed."

# ── Python virtual environment ───────────────────────────────────────────────
echo "[2/4] Setting up Python venv..."
if [ ! -d "${REPO_ROOT}/.venv" ]; then
    python3 -m venv "${REPO_ROOT}/.venv"
fi
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
    rich

echo "  Python venv ready at ${REPO_ROOT}/.venv"

# ── TeX Live (portable install) ──────────────────────────────────────────────
echo "[3/4] Installing TeX Live (this may take a while)..."
if [ -x "${TEXLIVE_DIR}/bin/x86_64-linux/tlmgr" ]; then
    echo "  TeX Live already installed. Updating..."
    "${TEXLIVE_DIR}/bin/x86_64-linux/tlmgr" update --self --all --quiet 2>/dev/null || true
else
    mkdir -p "${TEXLIVE_DIR}"
    TMPDIR=$(mktemp -d)
    cd "${TMPDIR}"

    echo "  Downloading TeX Live installer..."
    curl -sL "${TEXLIVE_INSTALLER_URL}" | tar xz

    echo "  Running installer (scheme-full, this takes ~10-20 min)..."
    ./install-tl-*/install-tl \
        --scheme=full \
        --portable \
        --installdir="${TEXLIVE_DIR}" \
        --texdir="${TEXLIVE_DIR}" \
        --texmflocal="${TEXLIVE_DIR}/texmf-local" \
        --tmpdir="${TMPDIR}" \
        --no-interaction \
        --quiet 2>&1

    cd "${REPO_ROOT}"
    rm -rf "${TMPDIR}"
    echo "  TeX Live installed."
fi

# Install essential extra packages that are commonly needed
TEXBIN="${TEXLIVE_DIR}/bin/x86_64-linux"
"${TEXBIN}/tlmgr" install \
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
    fancyhdr \
    geometry \
    xcolor \
    graphicx \
    titlesec \
    enumitem \
    caption \
    subcaption \
    float \
    placeins \
    tocloft \
    ntheorem \
    amsmath amssymb amsthm \
    algorithm2e \
    listings \
    pgfplots \
    tikz \
    2>/dev/null || true

echo "  TeX Live ready at ${TEXLIVE_DIR}"

# ── PATH & aliases ───────────────────────────────────────────────────────────
echo "[4/4] Configuring PATH and aliases..."

BASHRC="${HOME}/.bashrc"
MARKER="# >>> LaTeX Helper Swarm >>>"

# Remove old block if present
sed -i "/${MARKER}/,/# <<< LaTeX Helper Swarm <<</d" "${BASHRC}"

cat >> "${BASHRC}" <<EOF

${MARKER}
# LaTeX Helper Swarm environment
export SWARM_REPO="${REPO_ROOT}"
export PATH="${TEXLIVE_DIR}/bin/x86_64-linux:\${PATH}"
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
# <<< LaTeX Helper Swarm <<<
EOF

echo "  Aliases added to ~/.bashrc"

# ── Git LFS init ─────────────────────────────────────────────────────────────
cd "${REPO_ROOT}"
git lfs install 2>/dev/null || true

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "    source ~/.bashrc"
echo "    sw-venv              # activate python venv"
echo "    sw-latex myfile.tex  # compile latex"
echo "    sw-pull              # git pull"
echo "============================================"

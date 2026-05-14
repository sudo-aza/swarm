#!/usr/bin/env python3
"""
compile.py — Smart LaTeX compilation helper (v2.1).

Usage:
    python3 scripts/compile.py <file.tex> [options]

Options:
    --engine {pdflatex|xelatex|lualatex|auto}
        Compilation engine. Default: auto (detects from file content).
    --shell-escape
        Pass -shell-escape to the engine. Auto-enabled when minted usage is
        detected; can be toggled manually.
    --no-shell-escape
        Explicitly disable -shell-escape even if auto-detected.
    --clean
        Remove auxiliary files after a successful compilation.
    --watch
        Watch the source directory and recompile on changes.
    --passes {1,2,3}
        Maximum number of compilation passes (default: smart — runs only
        as many as needed based on bibliography and cross-references).
    --verbose
        Show full LaTeX output instead of just warnings.

Features:
    - Auto-detects bibliography engine (biber vs bibtex)
    - Auto-detects engine requirement (fontspec → lualatex/xelatex)
    - Auto-detects minted/tikz-externalize → enables -shell-escape
    - Smart multi-pass: skips unnecessary passes when possible
    - Shows warnings on success, full errors on failure
    - Watch mode with file extension filtering
    - Reports compilation time and output PDF size
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent

# Patterns that indicate -shell-escape is needed
SHELL_ESCAPE_TRIGGERS = [
    r"\\usepackage.*minted",
    r"\\begin\{minted\}",
    r"\\mintinline",
    r"\\pygmark",
    r"tikzexternalize",
    r"\\immediate\\write18",
]

# Patterns that require LuaLaTeX or XeLaTeX (not pdfLaTeX)
UNICODE_ENGINE_TRIGGERS = [
    r"\\usepackage.*fontspec",
    r"\\usepackage.*unicode-math",
    r"\\setmainfont",
    r"\\setsansfont",
    r"\\setmonofont",
]

# Warning patterns to extract from LaTeX output
LATEX_WARNING_RE = re.compile(r"^(.*(?:Warning|Overfull|Underfull).*)$", re.MULTILINE)
RERUN_RE = re.compile(
    r"LaTeX Warning: .*undefined references"
    r"|LaTeX Warning: .*Rerun to get cross-references right"
    r"|LaTeX Warning: .*Label\(s\) may have changed"
    r"|Please \(re\)?run (?:Biber|BibTeX|bibtex|biber)"
    r"|.*rerun (?:Biber|BibTeX|bibtex|biber)"
)


def find_texlive_bin() -> Optional[str]:
    """Locate the TeX Live binary directory.

    Search order:
      1. Repo-local portable install: <repo>/texlive/bin/<arch>/
      2. System PATH (returns None, letting subprocess use the system PATH)

    Supports x86_64-linux and aarch64-linux architectures.
    """
    for arch in ("x86_64-linux", "aarch64-linux"):
        local_bin = REPO_ROOT / "texlive" / "bin" / arch
        if local_bin.exists():
            return str(local_bin)
    return None


def detect_engine(tex_file: Path, user_choice: str) -> str:
    """Determine which LaTeX engine to use.

    If the user passes 'auto' (default), we scan the .tex source AND any
    locally-resolvable .sty/.cls files it loads for packages that require
    LuaLaTeX or XeLaTeX (e.g. fontspec, unicode-math).  If found we
    default to lualatex.  The user can always override explicitly.
    """
    if user_choice != "auto":
        return user_choice

    tex_content = tex_file.read_text(errors="ignore")

    for pattern in UNICODE_ENGINE_TRIGGERS:
        if re.search(pattern, tex_content):
            return "lualatex"

    # Scan locally-resolvable .sty/.cls files loaded by the document
    for match in re.finditer(r"\\usepackage(?:\[.*?\])?\{([^}]+)\}", tex_content):
        pkg_name = match.group(1).strip().split(",")[0].strip()
        sty = _resolve_sty(tex_file, pkg_name)
        if sty:
            sty_content = sty.read_text(errors="ignore")
            for pattern in UNICODE_ENGINE_TRIGGERS:
                if re.search(pattern, sty_content):
                    return "lualatex"

    return "pdflatex"


def _resolve_sty(tex_file: Path, pkg_name: str) -> Optional[Path]:
    """Try to find a .sty file for the given package name.

    Search order:
      1. Same directory as the .tex file
      2. <repo>/src/themes/
      3. <repo>/src/
    """
    candidates = [
        tex_file.parent / f"{pkg_name}.sty",
        REPO_ROOT / "src" / "themes" / f"{pkg_name}.sty",
        REPO_ROOT / "src" / f"{pkg_name}.sty",
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def detect_shell_escape(tex_file: Path, user_wants: Optional[bool]) -> bool:
    """Determine whether to pass -shell-escape.

    Priority:
      1. User explicitly set --shell-escape or --no-shell-escape.
      2. Auto-detect from .tex content AND locally-resolvable .sty files.

    Returns True if -shell-escape should be enabled.
    """
    if user_wants is not None:
        return user_wants

    tex_content = tex_file.read_text(errors="ignore")

    # Check the .tex file directly
    for pattern in SHELL_ESCAPE_TRIGGERS:
        if re.search(pattern, tex_content):
            return True

    # Also check loaded .sty/.cls files for minted, write18, etc.
    for match in re.finditer(r"\\usepackage(?:\[.*?\])?\{([^}]+)\}", tex_content):
        pkg_name = match.group(1).strip().split(",")[0].strip()
        sty = _resolve_sty(tex_file, pkg_name)
        if sty:
            sty_content = sty.read_text(errors="ignore")
            for pattern in SHELL_ESCAPE_TRIGGERS:
                if re.search(pattern, sty_content):
                    return True
            # Also check for \tcbuselibrary{minted} which is the actual trigger
            if r"tcbuselibrary" in sty_content and "minted" in sty_content:
                return True

    return False


def detect_bibliography(tex_content: str) -> Optional[str]:
    """Detect which bibliography backend is needed.

    Strips LaTeX comments before checking, to avoid false positives
    from commented-out bibliography commands.

    Returns 'biber' for biblatex, 'bibtex' for traditional \\bibliography,
    or None if no bibliography is referenced.
    """
    # Strip comments (% to end of line, but not escaped \%)
    stripped = re.sub(r"(?<!\\)%.*$", "", tex_content, flags=re.MULTILINE)

    if r"\addbibresource" in stripped:
        return "biber"
    if r"\bibliography" in stripped or r"\bibliographystyle" in stripped:
        return "bibtex"
    return None


def has_undefined_references(log_output: str) -> bool:
    """Check if the LaTeX log mentions undefined references or requests a rerun.

    Catches: undefined references, label changes, cross-reference reruns,
    and "Please (re)run Biber/BibTeX" messages from bib tools.
    """
    return bool(RERUN_RE.search(log_output))


def extract_warnings(output: str) -> list:
    """Extract warning lines from LaTeX output."""
    return LATEX_WARNING_RE.findall(output)


def build_command(
    engine: str,
    tex_file: Path,
    shell_escape: bool,
) -> list:
    """Build the LaTeX compilation command."""
    cmd = [engine, "-interaction=nonstopmode", "-file-line-error"]
    if shell_escape:
        cmd.append("-shell-escape")
    cmd.append(str(tex_file))
    return cmd


def _build_env(tex_file: Path, bin_path: Optional[str]) -> dict:
    """Build environment dict with PATH and TEXINPUTS set appropriately.

    TEXINPUTS is augmented so that local theme directories inside the
    repo are found automatically without requiring the user to set them.
    """
    env = os.environ.copy()
    if bin_path:
        env["PATH"] = bin_path + os.pathsep + env.get("PATH", "")

    # Auto-add repo-local theme directories to TEXINPUTS.
    # The trailing os.pathsep tells kpathsea to also search the standard
    # texmf tree after these directories (critical for luaotfload etc.).
    texinputs_dirs = [
        str(REPO_ROOT / "src" / "themes") + os.sep,
        str(REPO_ROOT / "src") + os.sep,
    ]
    existing = env.get("TEXINPUTS", "")
    env["TEXINPUTS"] = os.pathsep.join(texinputs_dirs) + os.pathsep
    if existing:
        env["TEXINPUTS"] += existing

    return env


def compile_tex(
    tex_file: Path,
    engine: str,
    bin_path: Optional[str],
    shell_escape: bool,
    max_passes: int,
    verbose: bool,
) -> dict:
    """Run LaTeX compilation with smart multi-pass logic.

    Strategy:
      - Always run at least 1 pass.
      - After the first pass, check if a bibliography is needed.
        If so, run the bib tool + 1 more pass.
      - After the final candidate pass, check the log for undefined
        references.  If found and we haven't hit max_passes, run
        another pass to resolve them.
      - With max_passes='smart' we cap at 3; the user can force more
        with --passes 4 etc.

    Returns a dict with success, elapsed, pdf_size, stdout, stderr,
    warnings, passes_run, bib_engine.
    """
    env = _build_env(tex_file, bin_path)

    tex_content = tex_file.read_text(errors="ignore")
    bib_engine = detect_bibliography(tex_content)
    cmd = build_command(engine, tex_file, shell_escape)
    workdir = tex_file.parent

    all_stdout = ""
    all_stderr = ""
    passes_run = 0
    smart_max = max_passes if max_passes > 0 else 3
    start = time.time()

    # ── Pass 1 ─────────────────────────────────────────────────────────────
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=workdir)
    all_stdout += result.stdout
    all_stderr += result.stderr
    passes_run += 1

    if result.returncode != 0:
        elapsed = time.time() - start
        pdf_size = _pdf_size(tex_file)
        warnings = extract_warnings(all_stdout)
        return _make_result(False, elapsed, pdf_size, all_stdout, all_stderr,
                            warnings, passes_run, bib_engine)

    # ── Bibliography pass (if needed) ──────────────────────────────────────
    if bib_engine and passes_run < smart_max:
        base = tex_file.stem
        bib_cmd = [bib_engine, base]
        subprocess.run(bib_cmd, env=env, capture_output=True, text=True, cwd=workdir)

        result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=workdir)
        all_stdout += result.stdout
        all_stderr += result.stderr
        passes_run += 1

    # ── Extra pass for cross-references or bib reruns ─────────────────────
    if has_undefined_references(all_stdout) and passes_run < smart_max:
        # If the rerun request is from Biber/BibTeX (not just cross-refs),
        # run the bib tool again before the extra LaTeX pass.
        if bib_engine and re.search(
            r"Please \(re\)?run (?:Biber|BibTeX|bibtex|biber)|"
            r"rerun (?:Biber|BibTeX|bibtex|biber)",
            all_stdout,
        ):
            bib_base = tex_file.stem
            bib_cmd = [bib_engine, bib_base]
            subprocess.run(bib_cmd, env=env, capture_output=True, text=True, cwd=workdir)

        result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=workdir)
        all_stdout += result.stdout
        all_stderr += result.stderr
        passes_run += 1

        # Check again — some complex documents need yet another pass
        if has_undefined_references(all_stdout) and passes_run < smart_max:
            if bib_engine and re.search(
                r"Please \(re\)?run (?:Biber|BibTeX|bibtex|biber)|"
                r"rerun (?:Biber|BibTeX|bibtex|biber)",
                all_stdout,
            ):
                bib_base = tex_file.stem
                subprocess.run([bib_engine, bib_base], env=env, capture_output=True,
                               text=True, cwd=workdir)
            result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=workdir)
            all_stdout += result.stdout
            all_stderr += result.stderr
            passes_run += 1

    elapsed = time.time() - start
    pdf_size = _pdf_size(tex_file)
    warnings = extract_warnings(all_stdout)
    success = result.returncode == 0

    return _make_result(success, elapsed, pdf_size, all_stdout, all_stderr,
                        warnings, passes_run, bib_engine)


def _pdf_size(tex_file: Path) -> int:
    """Return PDF file size in bytes, or 0 if not found."""
    pdf = tex_file.with_suffix(".pdf")
    return pdf.stat().st_size if pdf.exists() else 0


def _make_result(success, elapsed, pdf_size, stdout, stderr,
                 warnings, passes_run, bib_engine) -> dict:
    return {
        "success": success,
        "elapsed": elapsed,
        "pdf_size": pdf_size,
        "stdout": stdout,
        "stderr": stderr,
        "warnings": warnings,
        "passes_run": passes_run,
        "bib_engine": bib_engine,
    }


def clean_aux(tex_file: Path) -> int:
    """Remove auxiliary files and cache directories. Returns count removed."""
    base = tex_file.stem
    workdir = tex_file.parent
    extensions = [
        ".aux", ".log", ".toc", ".out", ".fls", ".fdb_latexmk",
        ".synctex.gz", ".bbl", ".blg", ".bcf", ".run.xml",
        ".lof", ".lot", ".nav", ".snm", ".vrb",
        "-blx.bib", ".ptc", ".glo", ".gls", ".ist", ".acn", ".acr",
        ".alg", ".glg", ".idx", ".ilg", ".ind", ".maf", ".mlf",
        ".mlt", ".mtc", ".mtc1", ".end",
    ]
    removed = 0
    # Remove auxiliary files by extension
    for ext in extensions:
        f = workdir / (base + ext)
        if f.exists():
            f.unlink()
            removed += 1
    # Remove minted cache directories (_minted-<filename>/)
    minted_prefix = f"_minted-{base}"
    for p in workdir.iterdir():
        if p.is_dir() and p.name.startswith("_minted-"):
            shutil.rmtree(p)
            removed += 1
    return removed


def format_result(result: dict, verbose: bool) -> str:
    """Format compilation result for terminal output."""
    lines = []

    if result["success"]:
        lines.append(
            f"Compilation successful in {result['elapsed']:.1f}s "
            f"({result['passes_run']} pass{'es' if result['passes_run'] != 1 else ''})"
        )
        if result["pdf_size"] > 0:
            lines.append(f"PDF size: {result['pdf_size'] / 1024:.0f} KB")

        if result["bib_engine"]:
            lines.append(f"Bibliography: {result['bib_engine']}")

        if result["warnings"]:
            lines.append(f"\nWarnings ({len(result['warnings'])}):")
            for w in result["warnings"][:20]:
                lines.append(f"  {w}")
            if len(result["warnings"]) > 20:
                lines.append(f"  ... and {len(result['warnings']) - 20} more")
    else:
        lines.append("Compilation FAILED.")
        lines.append(f"Engine output (last 25 lines):")
        output_lines = result["stdout"].strip().split("\n")
        for line in output_lines[-25:]:
            lines.append(f"  {line}")

        if result["stderr"] and not verbose:
            stderr_lines = result["stderr"].strip().split("\n")
            if any("fatal" in l.lower() or "error" in l.lower() for l in stderr_lines):
                lines.append(f"\nStderr (relevant lines):")
                for l in stderr_lines[-10:]:
                    lines.append(f"  {l}")

    if verbose and result["success"] and result["warnings"]:
        # In verbose mode, show full stdout
        lines.append(f"\nFull output (last 30 lines):")
        output_lines = result["stdout"].strip().split("\n")
        for line in output_lines[-30:]:
            lines.append(f"  {line}")

    return "\n".join(lines)


# ── Watch mode ──────────────────────────────────────────────────────────────

def watch_mode(tex_file: Path, engine: str, bin_path: Optional[str],
               shell_escape: bool, max_passes: int, verbose: bool):
    """Watch the source directory and recompile on file changes."""
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError:
        print("watchdog not installed. Install with: pip install watchdog")
        sys.exit(1)

    compile_extensions = {".tex", ".bib", ".sty", ".cls", ".lua", ".cfg", ".def"}
    debounce_seconds = 1.5
    last_compile_time = 0.0

    class Handler(FileSystemEventHandler):
        def on_modified(self, event):
            nonlocal last_compile_time
            if event.is_directory:
                return
            if Path(event.src_path).suffix not in compile_extensions:
                return

            now = time.time()
            if now - last_compile_time < debounce_seconds:
                return
            last_compile_time = now

            rel = os.path.relpath(event.src_path, tex_file.parent)
            print(f"\n--- Change detected: {rel} ---")
            result = compile_tex(tex_file, engine, bin_path, shell_escape,
                                 max_passes, verbose)
            print(format_result(result, verbose))

    observer = Observer()
    observer.schedule(Handler(), str(tex_file.parent), recursive=True)
    observer.start()
    print(f"Watching {tex_file.parent} for changes... Press Ctrl+C to stop.")

    # Initial compile
    print(f"\n--- Initial compilation ---")
    result = compile_tex(tex_file, engine, bin_path, shell_escape,
                         max_passes, verbose)
    print(format_result(result, verbose))

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping watch mode.")
        observer.stop()
    observer.join()


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Smart LaTeX compiler for the LaTeX Helper Swarm",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/compile.py src/templates/demo-beautiful.tex
  python3 scripts/compile.py paper.tex --engine lualatex --clean
  python3 scripts/compile.py slides.tex --watch --verbose
        """,
    )
    parser.add_argument("file", help="Path to .tex file")
    parser.add_argument(
        "--engine",
        choices=["pdflatex", "xelatex", "lualatex", "auto"],
        default="auto",
        help="Compilation engine (default: auto-detect from file content)",
    )
    shell_group = parser.add_mutually_exclusive_group()
    shell_group.add_argument(
        "--shell-escape",
        action="store_true",
        default=None,
        dest="shell_escape",
        help="Enable -shell-escape (auto-enabled for minted by default)",
    )
    shell_group.add_argument(
        "--no-shell-escape",
        action="store_false",
        dest="shell_escape",
        help="Disable -shell-escape even if auto-detected",
    )
    parser.add_argument(
        "--clean", "-c",
        action="store_true",
        help="Remove auxiliary files after successful compilation",
    )
    parser.add_argument(
        "--watch", "-w",
        action="store_true",
        help="Watch for file changes and recompile automatically",
    )
    parser.add_argument(
        "--passes",
        type=int,
        default=0,
        metavar="N",
        help="Max compilation passes (default: smart — runs as many as needed, up to 3)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show full LaTeX output",
    )
    args = parser.parse_args()

    tex_file = Path(args.file).resolve()
    if not tex_file.exists():
        print(f"Error: file not found: {tex_file}", file=sys.stderr)
        sys.exit(1)

    if tex_file.suffix.lower() != ".tex":
        print(f"Warning: {tex_file} does not have a .tex extension", file=sys.stderr)

    bin_path = find_texlive_bin()

    # Read file content for auto-detection
    tex_content = tex_file.read_text(errors="ignore")

    # Auto-detect engine (scans .tex + local .sty files)
    engine = detect_engine(tex_file, args.engine)

    # Auto-detect shell-escape (scans .tex + local .sty files)
    shell_escape = detect_shell_escape(tex_file, args.shell_escape)

    if args.verbose:
        print(f"Engine: {engine}")
        print(f"Shell-escape: {'on' if shell_escape else 'off'}")
        if bin_path:
            print(f"TeX Live: {bin_path}")
        else:
            print("TeX Live: system PATH")

    if args.watch:
        watch_mode(tex_file, engine, bin_path, shell_escape, args.passes,
                   args.verbose)
    else:
        result = compile_tex(tex_file, engine, bin_path, shell_escape,
                             args.passes, args.verbose)
        print(format_result(result, args.verbose))

        if args.clean and result["success"]:
            removed = clean_aux(tex_file)
            print(f"\nCleaned {removed} auxiliary file(s).")

        if not result["success"]:
            sys.exit(1)


if __name__ == "__main__":
    main()

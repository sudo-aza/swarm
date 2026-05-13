#!/usr/bin/env python3
"""
compile.py — Smart LaTeX compilation helper.

Usage:
    python3 scripts/compile.py <file.tex> [--engine {pdflatex|xelatex|lualatex}] [--clean] [--watch]

Features:
    - Auto-detects bibliography engine (bibtex vs biber)
    - Runs bibtex/biber if needed
    - Cleans aux files after success
    - Watch mode: recompiles on file changes
    - Reports compilation time and output size
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def find_texlive_bin():
    """Find the TeX Live binary directory."""
    # Check repo-local install
    local_bin = REPO_ROOT / "texlive" / "bin" / "x86_64-linux"
    if local_bin.exists():
        return str(local_bin)
    # Fall back to system
    return None


def get_engine(name: str) -> str:
    engines = {"pdflatex": "pdflatex", "xelatex": "xelatex", "lualatex": "lualatex"}
    return engines.get(name, "pdflatex")


def needs_bibtex(tex_file: Path) -> str | None:
    """Check if the tex file references bibliography."""
    content = tex_file.read_text(errors="ignore")
    if r"\bibliography" in content or r"\addbibresource" in content:
        if r"\addbibresource" in content:
            return "biber"
        return "bibtex"
    return None


def compile_tex(tex_file: Path, engine: str, bin_path: str | None):
    """Run LaTeX compilation with bib pass if needed."""
    env = os.environ.copy()
    if bin_path:
        env["PATH"] = bin_path + os.pathsep + env.get("PATH", "")

    base = tex_file.stem
    cmd = [engine, "-interaction=nonstopmode", "-file-line-error", str(tex_file)]

    start = time.time()
    # First pass
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=tex_file.parent)
    
    # Bibliography
    bib_engine = needs_bibtex(tex_file)
    if bib_engine:
        subprocess.run([bib_engine, base], env=env, capture_output=True, text=True, cwd=tex_file.parent)
        # Second pass after bib
        subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=tex_file.parent)

    # Third pass for references
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd=tex_file.parent)
    elapsed = time.time() - start

    pdf_file = tex_file.with_suffix(".pdf")
    pdf_size = pdf_file.stat().st_size if pdf_file.exists() else 0

    return {
        "success": result.returncode == 0,
        "elapsed": elapsed,
        "pdf_size": pdf_size,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


def clean_aux(tex_file: Path):
    """Remove auxiliary files."""
    base = tex_file.stem
    extensions = [".aux", ".log", ".toc", ".out", ".fls", ".fdb_latexmk",
                  ".synctex.gz", ".bbl", ".blg", ".bcf", ".run.xml", ".lof", ".lot"]
    for ext in extensions:
        f = tex_file.parent / (base + ext)
        if f.exists():
            f.unlink()


def watch(tex_file: Path, engine: str, bin_path: str | None):
    """Watch mode: recompile on changes."""
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError:
        print("Install watchdog: pip install watchdog")
        sys.exit(1)

    class Handler(FileSystemEventHandler):
        def on_modified(self, event):
            if event.src_path.endswith(('.tex', '.bib', '.sty', '.cls', '.lua')):
                print(f"\n--- Change detected: {event.src_path} ---")
                run_compile(tex_file, engine, bin_path, clean=False)

    def run_compile(tf, eng, bp, clean):
        result = compile_tex(tf, eng, bp)
        if result["success"]:
            print(f"  OK — {result['elapsed']:.1f}s, {result['pdf_size']/1024:.0f} KB")
        else:
            print(f"  FAILED — check log")

    observer = Observer()
    observer.schedule(Handler(), str(tex_file.parent), recursive=False)
    observer.start()
    print(f"Watching {tex_file.parent} for changes... Press Ctrl+C to stop.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


def main():
    parser = argparse.ArgumentParser(description="Smart LaTeX compiler")
    parser.add_argument("file", help="Path to .tex file")
    parser.add_argument("--engine", choices=["pdflatex", "xelatex", "lualatex"], default="pdflatex")
    parser.add_argument("--clean", action="store_true", help="Clean aux files after")
    parser.add_argument("--watch", action="store_true", help="Watch for changes and recompile")
    args = parser.parse_args()

    tex_file = Path(args.file).resolve()
    if not tex_file.exists():
        print(f"Error: {tex_file} not found")
        sys.exit(1)

    bin_path = find_texlive_bin()
    engine = get_engine(args.engine)

    if args.watch:
        watch(tex_file, engine, bin_path)
    else:
        result = compile_tex(tex_file, engine, bin_path)
        if result["success"]:
            print(f"Compilation successful in {result['elapsed']:.1f}s")
            print(f"PDF size: {result['pdf_size']/1024:.0f} KB")
            if args.clean:
                clean_aux(tex_file)
                print("Auxiliary files cleaned.")
        else:
            print("Compilation FAILED. Last 20 lines of output:")
            lines = result["stdout"].strip().split("\n")
            for line in lines[-20:]:
                print(f"  {line}")
            sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
spellcheck.py — LaTeX-aware spell checker for the Swarm toolkit (v1.0).

Usage:
    python3 scripts/spellcheck.py <file.tex> [options]

Options:
    --lang {en,en_GB,de,fr,...}
        Language for the spell checker (default: en).
        When using the hunspell backend this is passed as the dictionary name.
        When using pyspellchecker this selects the built-in language data.
    --backend {auto,pyspellchecker,hunspell}
        Spell checking backend (default: auto — tries hunspell first, falls
        back to pyspellchecker).
    --dict FILE
        Path to a custom dictionary file (one word per line). Words in this
        file are always treated as correct.  A project-local file
        ``.swarm-dictionary`` in the same directory as the .tex file is
        loaded automatically.
    --format {terminal,json,tex,inline}
        Output format (default: terminal).
        terminal — human-readable report to stdout.
        json     — machine-readable JSON to stdout.
        tex      — standalone LaTeX document with squiggly underlines.
        inline   — LaTeX helper for \\input in preamble (used with \\usepackage{spellcheck}).
    --output FILE
        Write output to FILE instead of stdout.  When --format=tex, defaults
        to ``<stem>-spellcheck.tex``.
    --ignore-patterns FILE
        Path to a file with additional regex patterns (one per line) for text
        that should be skipped (e.g. ``\\cite\\{.*?\\}``).
    --verbose, -v
        Show extra information (dictionary size, lines processed, etc.).

How it works:
    1. Reads the .tex source file.
    2. Strips LaTeX markup (commands, math mode, comments, URLs, citations,
       verbatim environments) to extract plain text with line tracking.
    3. Runs each extracted word through the spell checker.
    4. Reports misspellings with original line/column numbers.

LaTeX filtering details:
    - ``\\command``, ``\\command[opt]{arg}`` — command name and options stripped,
      argument text retained.
    - ``$...$`` and ``$$...$$`` — entire math expressions removed.
    - ``\\begin{verbatim}...\\end{verbatim}`` and similar literal environments
      — entire content removed.
    - ``%...`` — comments stripped.
    - ``\\cite{...}``, ``\\ref{...}``, ``\\label{...}`` — keys stripped.
    - ``\\url{...}``, ``\\href{...}{...}`` — URLs stripped.
    - Curly braces ``{}`` — removed (content kept).
    - Hyphenated words split into parts (each part checked independently).

Dependencies:
    - pyspellchecker (pip, pure Python) — always available, good English.
    - hunspell CLI (apt: hunspell + hunspell-<lang>) — optional, better
      multilingual support, used when available and ``--backend auto|huspnell``.

Examples:
    python3 scripts/spellcheck.py paper.tex
    python3 scripts/spellcheck.py paper.tex --format json --output report.json
    python3 scripts/spellcheck.py paper.tex --format tex --dict my-words.txt
    python3 scripts/spellcheck.py paper.tex --backend hunspell --lang en_GB
"""

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent

# ── LaTeX stripping patterns ───────────────────────────────────────────────

# Verbatim-like environments whose content must NOT be spell-checked.
LITERAL_ENVS = {
    "verbatim", "verbatim*", "lstlisting", "minted", "mint",
    "program", "programlisting", "console", "terminal",
    "codeblock", "code",  # swarmbeauty/swarmperf custom envs
}

# Math environments whose content must NOT be spell-checked.
MATH_ENVS = {
    "equation", "equation*", "align", "align*",
    "gather", "gather*", "multline", "multline*",
    "eqnarray", "eqnarray*", "math", "displaymath",
    "cases", "split", "aligned", "gathered",
}

# Environments whose argument text IS spell-checked (no special handling).
SAFE_ENVS = {
    "document", "itemize", "enumerate", "description", "quote",
    "quotation", "verse", "minipage", "center", "flushleft",
    "flushright", "figure", "table", "figure*", "table*",
}

# Commands whose argument(s) should NOT be spell-checked (keys/labels/URLs).
SKIP_ARG_COMMANDS = {
    "cite", "citep", "citet", "citeauthor", "citeyear", "nocite",
    "ref", "eqref", "autoref", "nameref", "pageref", "cref", "Cref",
    "label", "crefname", "Crefname",
    "url", "href", "hyperlink",
    "includegraphics", "include", "input", "import", "subfile",
    "bibliography", "bibliographystyle", "addbibresource",
    "usepackage", "documentclass",
    "usetheme", "usecolortheme", "usefonttheme",
    "definecolor", "colorlet", "setmainfont", "setsansfont", "setmonofont",
    "setlength", "setcounter", "newcommand", "renewcommand",
    "newenvironment", "renewenvironment",
    "titleformat", "titlelabel",
    "definekey", "setkeys",
    "catcode", "mathcode", "lccode", "uccode", "sfcode",
    "newcolumntype",
    "luaexec", "luadirect", "directlua",
}

# Commands that take no arguments and should be removed entirely.
SKIP_VOID_COMMANDS = {
    "par", "noindent", "newline", "linebreak", "pagebreak",
    "newpage", "clearpage", "cleardoublepage",
    "hfill", "vfill", "hspace", "vspace", "smallskip",
    "medskip", "bigskip", "vspace*", "hspace*",
    "centering", "raggedright", "raggedleft", "normalfont",
    "tiny", "scriptsize", "footnotesize", "small", "normalsize",
    "large", "Large", "LARGE", "huge", "Huge",
    "rmfamily", "sffamily", "ttfamily",
    "bfseries", "mdseries", "itshape", "slshape", "scshape",
    "upshape", "textnormal",
    "makeatletter", "makeatother",
    "mkern", "kern", "hskip", "vskip", "penalty",
    "unskip", "vadjust", "nointerlineskip",
    "allowdisplaybreaks",
    "frontmatter", "mainmatter", "backmatter",
    "appendix",
    "DisableLigatures", "EnableLigatures",
    "textbf", "textit", "texttt", "textrm", "textsf", "textsc",
    "textnormal", "textup", "textsl", "emph", "underline",
    "textcolor", "color", "colorbox", "fcolorbox",
    "footnotesize", "scriptsize",
    "hspace", "vspace",
}


# ── LaTeX-to-text extraction ───────────────────────────────────────────────

class TexExtractor:
    """Extract plain text from LaTeX source while preserving line tracking.

    Each word is annotated with the original line number so that
    misspellings can be reported with file-level coordinates.
    """

    def __init__(self, source: str, filename: str = ""):
        self.source = source
        self.filename = filename
        self.lines = source.split("\n")
        self.words: List[Tuple[str, int]] = []  # (word, line_number)

    def extract(self) -> List[Tuple[str, int]]:
        """Run full extraction pipeline.  Returns list of (word, line)."""
        text = self._preprocess()
        self._parse(text)
        return self.words

    # ── Preprocessing ───────────────────────────────────────────────────

    def _preprocess(self) -> str:
        """Strip literal environments and comments line-by-line."""
        result_lines = []
        i = 0
        while i < len(self.lines):
            line = self.lines[i]

            # Strip LaTeX comments (but not escaped \%)
            line = re.sub(r"(?<!\\)%.*$", "", line)

            # Sort by length descending so longer env names (e.g.
            # "codeblock") match before shorter prefixes (e.g. "code").
            # Unsorted sets have non-deterministic iteration order due to
            # PYTHONHASHSEED, which can cause the regex to match the
            # wrong environment and silently skip the rest of the file.
            env_names = sorted(LITERAL_ENVS | MATH_ENVS, key=len, reverse=True)
            m = re.match(
                r"^\s*\\begin\{(" +
                "|".join(re.escape(e) for e in env_names) +
                r")", line)
            if m:
                env_name = m.group(1)
                end_pat = re.compile(r"^\s*\\end\{" + re.escape(env_name) + r"\}")
                # Skip until matching \end
                i += 1
                while i < len(self.lines):
                    if end_pat.match(self.lines[i]):
                        break
                    i += 1
                i += 1
                continue

            # Strip multi-line display math: \[...\] and $$...$$
            # (single-line math is handled later by _strip_math())
            m = re.match(r'^\s*(\\\[|\$\$)', line)
            if m:
                delim = m.group(1)
                # Escape for regex: \[ -> \\\[, $$ -> \$\$
                if delim == r'\[':
                    end_pat = re.compile(r'^\s*\\\]')
                else:
                    end_pat = re.compile(r'^\s*\$\$')
                i += 1
                while i < len(self.lines):
                    if end_pat.match(self.lines[i]):
                        break
                    i += 1
                i += 1
                continue

            result_lines.append(line)
            i += 1

        return "\n".join(result_lines)

    # ── Parsing ─────────────────────────────────────────────────────────

    def _parse(self, text: str) -> None:
        """Parse preprocessed text into words with line tracking.

        Uses a simple state machine approach: iterate character by character,
        track current line number, and handle LaTeX constructs inline.
        """
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i]
            line_no = i + 1  # 1-indexed

            # Strip math mode ($...$ and $$...$$) from this line
            line = self._strip_math(line)

            # Strip skip-arg commands: \cite{...}, \ref{...}, \url{...}, etc.
            line = self._strip_skip_arg_commands(line)

            # Process line character by character
            self._process_line(line, line_no)
            i += 1

    def _strip_math(self, line: str) -> str:
        """Remove inline and display math from a single line.

        Handles: ``$...$``, ``$$...$$``, ``\\[...\\]``, ``\\(...\\)``.
        Simple greedy matching — does not handle nested environments
        (which is acceptable for spell checking purposes).
        """
        # Display math $$...$$
        line = re.sub(r"\$\$.*?\$\$", "", line)
        # Inline math $...$ (be careful not to match \$)
        line = re.sub(r"(?<!\\)\$(?!\$).*?(?<!\\)\$", "", line)
        # \[...\] display math
        line = re.sub(r"\\\[.*?\\\]", "", line)
        # \(...\) inline math
        line = re.sub(r"\\\(.*?\\\)", "", line)
        return line

    def _strip_skip_arg_commands(self, line: str) -> str:
        """Remove commands whose arguments should not be spell-checked.

        Examples: ``\\cite{key}``, ``\\ref{label}``, ``\\url{http://...}``.
        """
        for cmd in SKIP_ARG_COMMANDS:
            # \cmd[opt]{arg} or \cmd{arg1}{arg2}...
            # Remove the entire command including all its arguments
            pattern = r"\\" + re.escape(cmd) + r"(?:\[[^\]]*\])?(?:\{[^}]*\})*"
            line = re.sub(pattern, "", line)
        return line

    def _process_line(self, line: str, line_no: int) -> None:
        """Extract words from a single line, handling LaTeX constructs."""
        pos = 0
        n = len(line)

        while pos < n:
            ch = line[pos]

            # Skip whitespace
            if ch in " \t\r":
                pos += 1
                continue

            # Skip escaped characters (\%, \&, etc.)
            if ch == "\\" and pos + 1 < n and line[pos + 1] in "%&$_#{}~^":
                pos += 2
                continue

            # Handle backslash commands
            if ch == "\\":
                cmd_end = self._find_command_end(line, pos)
                if cmd_end > pos:
                    cmd_name = self._get_command_name(line, pos)
                    if cmd_name and cmd_name.lower() in SKIP_VOID_COMMANDS:
                        pos = cmd_end
                        continue
                    # For other commands, skip the command name but
                    # keep the argument text (it will be processed below
                    # when we hit the { character).
                    # Skip to the opening brace or end of command token.
                    arg_start = self._find_arg_start(line, pos, cmd_end)
                    if arg_start < cmd_end:
                        pos = arg_start
                        continue
                    pos = cmd_end
                    continue

            # Handle braces: skip { and } but keep content
            if ch in "{}":
                pos += 1
                continue

            # Handle brackets (optional arguments): skip content
            if ch == "[":
                depth = 1
                pos += 1
                while pos < n and depth > 0:
                    if line[pos] == "[":
                        depth += 1
                    elif line[pos] == "]":
                        depth -= 1
                    pos += 1
                continue

            # Handle URLs and emails
            if ch in ("<", "@") or (ch == "h" and line[pos:pos+4] == "http"):
                url_end = self._find_url_end(line, pos)
                pos = url_end
                continue

            # Collect a word token
            word_start = pos
            while pos < n and not line[pos] in " \t\r\\{}[]$%<>@~|":
                pos += 1

            if pos > word_start:
                token = line[word_start:pos]
                # Handle trailing punctuation
                stripped = token.strip(".,;:!?\"'()[]")
                if stripped:
                    # Split hyphenated words
                    parts = re.split(r"[-/]", stripped)
                    for part in parts:
                        clean = part.strip("'\"")
                        if clean and len(clean) > 1 and not clean.isdigit():
                            self.words.append((clean, line_no))
            else:
                # No progress made — advance past this character to
                # avoid an infinite loop (e.g. on standalone punctuation
                # like >, <, @, #, etc. that are not word characters).
                pos += 1

    def _find_command_end(self, line: str, pos: int) -> int:
        """Find the end of a LaTeX command starting at pos (the backslash).

        Handles: ``\\cmd``, ``\\cmd[opt]{arg}``, ``\\cmd[opt]{arg}{arg2}``.
        Returns the position after the last consumed character.
        """
        i = pos + 1  # skip backslash
        n = len(line)

        # Read command name (letters only)
        while i < n and line[i].isalpha():
            i += 1

        if i == pos + 1:
            # Single-character command (\\, \%, etc.)
            return i + 1 if i < n else i

        # Skip optional arguments [...]
        while i < n:
            if line[i] in " \t":
                i += 1
                continue
            if line[i] == "[":
                depth = 1
                i += 1
                while i < n and depth > 0:
                    if line[i] == "[":
                        depth += 1
                    elif line[i] == "]":
                        depth -= 1
                    i += 1
                continue
            break

        # Skip mandatory arguments {...}
        while i < n:
            if line[i] in " \t":
                i += 1
                continue
            if line[i] == "{":
                depth = 1
                i += 1
                while i < n and depth > 0:
                    if line[i] == "{":
                        depth += 1
                    elif line[i] == "}":
                        depth -= 1
                    i += 1
                continue
            break

        return i

    def _find_arg_start(self, line: str, cmd_start: int, cmd_end: int) -> int:
        """Check if a command has arguments that contain spell-checkable text.

        Returns a position inside the first ``{arg}`` if found, or cmd_end.
        """
        i = cmd_end
        n = len(line)

        # Look for optional args first
        while i < n and line[i] in " \t":
            i += 1
        if i < n and line[i] == "[":
            depth = 1
            i += 1
            while i < n and depth > 0:
                if line[i] == "[":
                    depth += 1
                elif line[i] == "]":
                    depth -= 1
                i += 1

        # Look for mandatory args
        while i < n and line[i] in " \t":
            i += 1
        if i < n and line[i] == "{":
            # Return position inside the brace (skip the {)
            return i + 1

        return cmd_end

    def _get_command_name(self, line: str, pos: int) -> Optional[str]:
        """Extract the command name (without backslash) starting at pos."""
        i = pos + 1
        while i < len(line) and line[i].isalpha():
            i += 1
        return line[pos + 1:i] if i > pos + 1 else None

    def _find_url_end(self, line: str, pos: int) -> int:
        """Find the end of a URL-like token starting at pos."""
        n = len(line)
        # Match http:// or https://
        if line[pos:pos+7] in ("http://", "https://"):
            i = pos + 7
            while i < n and line[i] not in " \t\r\\{}[]$%<>,":
                i += 1
            return i
        # Match <url> pattern
        if line[pos] == "<":
            i = pos + 1
            while i < n and line[i] != ">":
                i += 1
            return min(i + 1, n) if i < n else i
        # Match email-like patterns (something@something)
        if line[pos] == "@":
            return pos + 1  # just skip the @
        return pos + 1


# ── Spell checking backends ────────────────────────────────────────────────

class SpellCheckResult:
    """A single misspelling result."""

    __slots__ = ("word", "line", "col", "suggestions")

    def __init__(self, word: str, line: int, col: int = 0,
                 suggestions: Optional[List[str]] = None):
        self.word = word
        self.line = line
        self.col = col
        self.suggestions = suggestions or []


class SpellBackend:
    """Abstract base for spell checking backends."""

    def check_words(self, words: List[Tuple[str, int]],
                    extra_dict: Set[str]) -> List[SpellCheckResult]:
        raise NotImplementedError

    @property
    def name(self) -> str:
        raise NotImplementedError


class PySpellCheckerBackend(SpellBackend):
    """Backend using pyspellchecker (pure Python).

    Good for English.  Falls back gracefully for other languages
    (defaults to English word list).
    """

    def __init__(self, lang: str = "en"):
        try:
            from spellchecker import SpellChecker
        except ImportError:
            print("Error: pyspellchecker not installed.\n"
                  "  Install with: pip install pyspellchecker\n"
                  "  Or use --backend hunspell if hunspell is available.",
                  file=sys.stderr)
            sys.exit(1)

        # pyspellchecker uses 'en' by default; other languages may not
        # have built-in data.  Map common aliases.
        lang_map = {"en": "en", "en_US": "en", "en_GB": "en"}
        effective_lang = lang_map.get(lang, "en")

        self._checker = SpellChecker(language=effective_lang)
        self._lang = lang

    @property
    def name(self) -> str:
        return f"pyspellchecker ({self._lang})"

    def check_words(self, words: List[Tuple[str, int]],
                    extra_dict: Set[str]) -> List[SpellCheckResult]:
        if not words:
            return []

        # Add custom dictionary words
        self._checker.word_frequency.load_words(extra_dict)

        # Batch: check all words at once for speed
        word_list = [w for w, _ in words]
        unknown = self._checker.unknown(word_list)

        results = []
        for word, line in words:
            if word.lower() in (u.lower() for u in unknown):
                # Get suggestions (limited to top 5)
                cands = self._checker.candidates(word)
                if cands is None:
                    cands = set()
                suggestions = sorted(cands - {word})[:5]
                results.append(SpellCheckResult(word, line, 0, suggestions))

        return results


class HunspellBackend(SpellBackend):
    """Backend using the hunspell CLI.

    Requires: ``hunspell`` binary on PATH and language dictionary
    installed (e.g. ``hunspell-en-us``).
    """

    def __init__(self, lang: str = "en_US"):
        self._lang = lang
        # Check hunspell is available
        try:
            result = subprocess.run(
                ["hunspell", "--version"],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode != 0:
                raise FileNotFoundError
        except (FileNotFoundError, subprocess.TimeoutExpired):
            print("Error: hunspell not found on PATH.\n"
                  "  Install with: sudo apt install hunspell hunspell-en-us\n"
                  "  Or use --backend pyspellchecker.",
                  file=sys.stderr)
            sys.exit(1)

    @property
    def name(self) -> str:
        return f"hunspell ({self._lang})"

    def check_words(self, words: List[Tuple[str, int]],
                    extra_dict: Set[str]) -> List[SpellCheckResult]:
        if not words:
            return []

        # Build hunspell input: one word per line
        input_text = "\n".join(w for w, _ in words) + "\n"

        # Write custom dict to a temp file if we have extra words
        import tempfile
        dict_words = extra_dict | {
            "LaTeX", "TeX", "LuaLaTeX", "XeLaTeX", "pdfLaTeX",
            "LuaTeX", "XeTeX", "pdfTeX",
            "KOMA", "TikZ", "tikz", "Beamer",
            "kwargs", "args", "str", "int", "bool", "float",
        }

        dict_file = None
        try:
            fd, dict_path = tempfile.mkstemp(suffix=".dic", prefix="swarm-spell-")
            dict_file = os.fdopen(fd, "w")
            dict_file.write(f"{len(dict_words)}\n")
            for w in sorted(dict_words):
                dict_file.write(w + "\n")
            dict_file.close()

            # Run hunspell in list mode (-l) with personal dictionary
            cmd = [
                "hunspell", "-d", self._lang, "-p", dict_path,
                "-l",  # list misspelled words only
            ]
            result = subprocess.run(
                cmd, input=input_text, capture_output=True, text=True,
                timeout=30,
            )

            # Parse hunspell output: one misspelled word per line
            misspelled = set()
            if result.stdout:
                for line in result.stdout.strip().split("\n"):
                    word = line.strip().lower()
                    if word:
                        misspelled.add(word)

            # Match back to original words with line numbers
            results = []
            for word, line in words:
                if word.lower() in misspelled:
                    results.append(SpellCheckResult(word, line))
            return results

        finally:
            if dict_file:
                dict_file.close()
            if dict_path:
                try:
                    os.unlink(dict_path)
                except OSError:
                    pass


def create_backend(backend_choice: str, lang: str) -> SpellBackend:
    """Create a spell checking backend based on user choice.

    When backend_choice is 'auto', tries hunspell first and falls back
    to pyspellchecker.
    """
    if backend_choice == "hunspell":
        return HunspellBackend(lang)

    if backend_choice == "pyspellchecker":
        return PySpellCheckerBackend(lang)

    # auto: try hunspell first
    try:
        result = subprocess.run(
            ["hunspell", "--version"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return HunspellBackend(lang)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return PySpellCheckerBackend(lang)


# ── Output formatters ──────────────────────────────────────────────────────

def format_terminal(results: List[SpellCheckResult], source_file: str,
                    total_words: int, elapsed: float,
                    backend_name: str) -> str:
    """Format results for terminal output."""
    lines = []
    lines.append(f"Spell check: {source_file}")
    lines.append(f"  Backend: {backend_name}")
    lines.append(f"  Words checked: {total_words}")
    lines.append(f"  Misspellings: {len(results)}")
    lines.append(f"  Time: {elapsed:.2f}s")
    lines.append("")

    if not results:
        lines.append("No misspellings found.")
        return "\n".join(lines)

    # Group by line
    by_line: Dict[int, List[SpellCheckResult]] = {}
    for r in results:
        by_line.setdefault(r.line, []).append(r)

    for line_no in sorted(by_line.keys()):
        items = by_line[line_no]
        words_str = ", ".join(f'"{r.word}"' for r in items)
        lines.append(f"  Line {line_no:>4}: {words_str}")
        # Show suggestions for first misspelling on this line
        for r in items:
            if r.suggestions:
                sugg_str = ", ".join(r.suggestions[:5])
                lines.append(f"           -> suggestions: {sugg_str}")
                break

    return "\n".join(lines)


def format_json(results: List[SpellCheckResult], source_file: str,
                total_words: int, elapsed: float,
                backend_name: str) -> str:
    """Format results as JSON."""
    data = {
        "file": source_file,
        "backend": backend_name,
        "words_checked": total_words,
        "misspellings": len(results),
        "time_seconds": round(elapsed, 3),
        "errors": [
            {
                "word": r.word,
                "line": r.line,
                "suggestions": r.suggestions,
            }
            for r in results
        ],
    }
    return json.dumps(data, indent=2)


def format_inline(results: List[SpellCheckResult], source_file: str,
                  total_words: int, elapsed: float,
                  backend_name: str) -> str:
    """Generate inline LaTeX helper for \\input in document preamble.

    Produces a .tex file that, when input before \\begin{document},
    provides the \\spellerror{} command and registers all misspelled
    words.  Users add \\usepackage{spellcheck} and \\input{<file>}
    to their preamble.
    """
    lines = []
    lines.append(r"% Spellcheck marks — auto-generated by spellcheck.py")
    lines.append(f"% Source: {source_file}")
    lines.append(f"% Backend: {backend_name}")
    lines.append(f"% Words checked: {total_words}, misspellings: {len(results)}")
    lines.append(f"% Usage: add \\usepackage{{spellcheck}} and \\input{{this file}} to preamble")
    lines.append("")

    # Unique misspelled words (deduplicate same word on multiple lines)
    seen = set()
    for r in results:
        if r.word not in seen:
            seen.add(r.word)
            # Escape special LaTeX characters
            escaped = (r.word
                .replace("\\", r"\\textbackslash")
                .replace("{", r"\\{")
                .replace("}", r"\\}")
                .replace("$", r"\\$")
                .replace("&", r"\\&")
                .replace("#", r"\\#")
                .replace("^", r"\\textasciicircum")
                .replace("_", r"\\_")
                .replace("~", r"\\textasciitilde")
                .replace("%", r"\\%"))
            lines.append(f"\\spellexport{{{escaped}}}")

    lines.append("")
    return "\n".join(lines)


def format_tex(results: List[SpellCheckResult], source_file: str,
               total_words: int, elapsed: float,
               backend_name: str) -> str:
    """Generate LaTeX markup for rendering squiggly underlines.

    Outputs a self-contained .tex file that, when compiled with LuaLaTeX,
    renders the original text with red squiggly underlines on misspelled
    words.  Uses TikZ zigzag decoration (see task #28 for theme integration).

    This is the bridge between the spell checker and PDF-visible output.
    Task #28 will integrate this into the swarm themes with toggle support.
    """
    lines = []
    lines.append(r"\documentclass{article}")
    lines.append(r"\usepackage[T1]{fontenc}")
    lines.append(r"\usepackage{lmodern}")
    lines.append(r"\usepackage{tikz}")
    lines.append(r"\usetikzlibrary{decorations.pathmorphing}")
    lines.append("")
    lines.append(r"% Spellcheck underline command (red zigzag)")
    lines.append(r"\newcommand{\spellerror}[1]{%")
    lines.append(r"  \tikz[baseline=(X.base)]{%")
    lines.append(r"    \node[inner sep=0pt,outer sep=0pt] (X) {#1};")
    lines.append(r"    \draw[red,decorate,decoration={zigzag,segment length=2pt,amplitude=0.4pt}]")
    lines.append(r"      (X.south west) -- (X.south east);")
    lines.append(r"  }%")
    lines.append(r"}")
    lines.append("")
    lines.append(r"\begin{document}")
    lines.append(f"% Source: {source_file}")
    lines.append(f"% Backend: {backend_name}")
    lines.append(f"% Words checked: {total_words}")
    lines.append(f"% Misspellings: {len(results)}")
    lines.append("")

    if not results:
        lines.append("No misspellings found. All words are correctly spelled.")
    else:
        lines.append(r"\section*{Spell Check Report}")
        lines.append(f"\\textbf{{File:}} {source_file}\\\\")
        lines.append(f"\\textbf{{Misspellings:}} {len(results)} of {total_words} words checked\\\\[1em]")
        lines.append(r"\begin{itemize}")
        for r in results:
            sugg = r.suggestions[0] if r.suggestions else "?"
            lines.append(
                f"  \\item Line {r.line}: "
                f"\\spellerror{{{r.word}}} "
                f"-- did you mean \\textit{{{sugg}}}?"
            )
        lines.append(r"\end{itemize}")

    lines.append("")
    lines.append(r"\end{document}")
    return "\n".join(lines)


# ── Custom dictionary loading ──────────────────────────────────────────────

DEFAULT_DICT_WORDS = {
    # LaTeX/TeX terms
    "LaTeX", "TeX", "LuaLaTeX", "XeLaTeX", "pdfLaTeX",
    "LuaTeX", "XeTeX", "pdfTeX", "ConTeXt",
    "KOMA", "TikZ", "Beamer", "minted", "tcolorbox",
    "biblatex", "biber", "bibtex",
    "fontspec", "unicode-math", "polyglossia", "csquotes",
    "hyperref", "cleveref", "autoref", "nameref",
    "booktabs", "tabularray", "arrayrulecolor",
    "scrlayer", "scrpage", "tocbasic", "typearea",
    "paracol", "wrapfig", "floatflt", "shapepar",
    "multicol", "enumitem", "caption", "minipage",
    "indiscernibles", "indiscernible",  # mathematical term
    # Programming/tech terms commonly used in LaTeX docs
    "kwargs", "args", "stdout", "stderr", "stdin",
    "autocomplete", "codebase", "endfor", "endif",
    "subagent", "subagents",
    # Common names in this project
    "swarmbeauty", "swarmperf", "swarmmin",
    # Typography and font terms
    "microtype", "Microtypographic", "OpenType", "TrueType",
    "Pygments", "ligatures", "kerning", "protrusion",
    "expansion", "asymmetric", "swash", " stylistic",
    "fontsize", "glyph", "glyphs", "serif", "sans",
    "monospace", "typographic",
    # Common domain words in technical writing
    "workflow", "workflows", "toolkit", "toolkits",
    "reproducible", "reproducibility", "benchmarking",
    "autodetection", "auto-detect", "auto-detected",
    "usecases", "usecase", "underlines",
    # Tabularray / table syntax terms
    "colspec", "hline", "vlines", "rowsep", "colsep",
    # Swarm theme color names
    "sbPrimary", "sbSecondary", "sbMedium", "sbDark",
    "sbLight", "sbCodeBg", "sbCodeFg", "sbAccent",
    "spGreen", "spOrange", "spDark", "spLight", "spMedium",
    # Abbreviations and compound words
    "PDF", "HTML", "JSON", "CLI", "API", "URL",
    "auto", "config", "dir", "env", "exec", "filename",
    "filepath", "log", "repo", "submodule", "untracked",
    "backend", "frontend", "keybinding", "recompile",
    "timestamp", "timeout", "toolchain", "verbose",
    "codeblock", "typeset", "typesetting", "tokenization",
    "uncommented", "parameterless", "subdirectory",
    # LaTeX abbreviations
    "TOC", "LOF", "LOT",
}


def load_custom_dict(tex_file: Path, dict_file: Optional[Path]) -> Set[str]:
    """Load custom dictionary from explicit file and/or project-local file.

    Priority: explicit --dict file > .swarm-dictionary in .tex dir > defaults.
    """
    words = set(DEFAULT_DICT_WORDS)

    # Project-local dictionary
    project_dict = tex_file.parent / ".swarm-dictionary"
    if project_dict.exists():
        for line in project_dict.read_text(errors="ignore").split("\n"):
            word = line.strip()
            if word and not word.startswith("#"):
                words.add(word)

    # Explicit dictionary file
    if dict_file and dict_file.exists():
        for line in dict_file.read_text(errors="ignore").split("\n"):
            word = line.strip()
            if word and not word.startswith("#"):
                words.add(word)

    return words


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="LaTeX-aware spell checker for the Swarm toolkit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/spellcheck.py paper.tex
  python3 scripts/spellcheck.py paper.tex --format json --output report.json
  python3 scripts/spellcheck.py paper.tex --format tex
  python3 scripts/spellcheck.py paper.tex --backend hunspell --lang en_GB
  python3 scripts/spellcheck.py paper.tex --dict my-words.txt
        """,
    )
    parser.add_argument("file", help="Path to .tex file")
    parser.add_argument(
        "--lang", default="en",
        help="Language code (default: en). For hunspell: en_US, en_GB, de, fr, etc.",
    )
    parser.add_argument(
        "--backend",
        choices=["auto", "pyspellchecker", "hunspell"],
        default="auto",
        help="Spell checking backend (default: auto)",
    )
    parser.add_argument(
        "--dict", type=Path, default=None,
        help="Path to custom dictionary file (one word per line)",
    )
    parser.add_argument(
        "--format",
        choices=["terminal", "json", "tex", "inline"],
        default="terminal",
        help="Output format (default: terminal). 'inline' generates a "
        ".tex helper file for \\input in document preamble.",
    )
    parser.add_argument(
        "--output", "-o", type=Path, default=None,
        help="Write output to FILE (default: stdout)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show extra information",
    )
    args = parser.parse_args()

    # ── Validate input ─────────────────────────────────────────────────
    tex_file = Path(args.file).resolve()
    if not tex_file.exists():
        print(f"Error: file not found: {tex_file}", file=sys.stderr)
        sys.exit(1)

    source = tex_file.read_text(errors="ignore")
    if not source.strip():
        print(f"Error: file is empty: {tex_file}", file=sys.stderr)
        sys.exit(1)

    # ── Load custom dictionary ─────────────────────────────────────────
    extra_dict = load_custom_dict(tex_file, args.dict)
    if args.verbose:
        print(f"Custom dictionary: {len(extra_dict)} words loaded")

    # ── Extract text from LaTeX ────────────────────────────────────────
    import time
    t0 = time.time()

    extractor = TexExtractor(source, str(tex_file))
    words = extractor.extract()

    if args.verbose:
        print(f"Extracted {len(words)} words from {tex_file.name}")

    # ── Run spell checker ──────────────────────────────────────────────
    backend = create_backend(args.backend, args.lang)
    if args.verbose:
        print(f"Backend: {backend.name}")

    results = backend.check_words(words, extra_dict)

    elapsed = time.time() - t0

    # ── Format output ──────────────────────────────────────────────────
    formatters = {
        "terminal": format_terminal,
        "json": format_json,
        "tex": format_tex,
        "inline": format_inline,
    }
    output = formatters[args.format](
        results, str(tex_file), len(words), elapsed, backend.name
    )

    # ── Write output ───────────────────────────────────────────────────
    if args.output:
        out_path = args.output
    elif args.format in ("tex", "inline"):
        out_path = tex_file.with_name(tex_file.stem + "-spellcheck.tex")
    else:
        out_path = None

    if out_path:
        out_path.write_text(output + "\n")
        print(f"Output written to: {out_path}")
    else:
        print(output)

    # Exit with non-zero if misspellings found (useful for CI)
    if results:
        sys.exit(1)


if __name__ == "__main__":
    main()

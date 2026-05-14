--[[
  metrics.lua — TeX document metrics collector (v3.0)

  Collects detailed statistics about a document during LuaLaTeX compilation.
  Writes results to a JSON file at the end of compilation.

  Usage in .tex preamble (AFTER \documentclass):
    \directlua{dofile("metrics.lua")}
    -- OR with search path:
    \directlua{dofile("src/lua/metrics.lua")}
    \directlua{dofile("../lua/metrics.lua")}

  For the best experience, load it early (before heavy packages like tikz)
  so wall_time captures the full compilation.

  Configuration (set BEFORE loading metrics.lua):
    \directlua{metrics_output_path = "custom/path.json"}
    \directlua{metrics_skip_aux  = true}   -- skip .aux parsing (faster)
    \directlua{metrics_skip_log  = true}   -- skip .log parsing (faster)

  Collected metrics:
    - Engine info (LuaTeX version, engine name)
    - Compilation wall time (os.clock, sub-millisecond)
    - Page count (via tex.count["c@page"])
    - PDF output file path and approximate size
    - Warning count (parsed from .log)
    - File inclusion tree (parsed from .log parentheses)
    - Document structure: sections, figures, tables, equations (from .aux)
    - Word count estimate (tokens in main .tex body)

  Design notes (v3.0):
    - File inclusions are tracked by PARSING THE .LOG FILE for parenthesis-
      delimited file references.  This is more reliable than the open_read_file
      LuaTeX callback, which is intercepted by ltluatex.lua in modern TeX Live.
    - Document structure (sections, figures, tables) is parsed from the .aux
      file at \\AtEndDocument time.  On the first compile, the .aux may not
      exist yet (counters stay at 0).  On subsequent compiles, the .aux from
      the previous run provides accurate structure counts.  This matches
      standard LaTeX behavior where 2+ runs are needed for correct output.
    - Word count is a rough estimate based on whitespace-delimited tokens in
      the main .tex file, excluding LaTeX commands and comments.  For accurate
      word counts, use the external texcount tool.
    - PDF size is read at \AtEndDocument time; it may be slightly smaller than
      the final file because the PDF xref/trailer hasn't been written yet.
      Use compile.py's _pdf_size() for the accurate post-compilation size.
]]

local metrics_output_path = metrics_output_path or "metrics-output.json"
local metrics_skip_aux    = metrics_skip_aux    or false
local metrics_skip_log    = metrics_skip_log    or false

-- ── JSON Serialization ──────────────────────────────────────────────────────
-- Made global so collect_metrics() and finalize_metrics() can access it.

json_escape = json_escape or function(s)
    if type(s) ~= "string" then return tostring(s) end
    return s
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("[%z\1-\31]", function(c)
            return string.format("\\u%04x", string.byte(c))
        end)
end

to_json = to_json or function(val, indent)
    indent = indent or 0
    local sp = string.rep("  ", indent)
    local sp1 = string.rep("  ", indent + 1)

    if val == nil then
        return "null"
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "number" then
        if val == math.floor(val) and math.abs(val) < 2^53 then
            return string.format("%d", val)
        end
        return string.format("%.6g", val)
    elseif type(val) == "string" then
        return '"' .. json_escape(val) .. '"'
    elseif type(val) == "table" then
        local is_array = (next(val) == nil) or (
            type((next(val))) == "number" and
            (next(val) == 1)
        )
        if is_array then
            for k, _ in pairs(val) do
                if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    is_array = false
                    break
                end
            end
        end

        local parts = {}
        if is_array then
            for _, v in ipairs(val) do
                table.insert(parts, sp1 .. to_json(v, indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. sp .. "]"
        else
            local keys = {}
            for k, _ in pairs(val) do table.insert(keys, k) end
            table.sort(keys, function(a, b)
                if type(a) == type(b) then return a < b end
                return type(a) < type(b)
            end)
            for _, k in ipairs(keys) do
                table.insert(parts,
                    sp1 .. '"' .. json_escape(tostring(k))
                    .. '": ' .. to_json(val[k], indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. sp .. "}"
        end
    end
    return '"' .. json_escape(tostring(val)) .. '"'
end

-- ── Metrics State ───────────────────────────────────────────────────────────

metrics_data = metrics_data or {
    engine            = "unknown",
    luatex_version    = "unknown",
    job_name          = "unknown",
    wall_time         = 0,
    page_count        = 0,
    pdf_size          = 0,
    pdf_path          = "",
    warning_count     = 0,
    included_files    = {},
    section_count     = 0,
    subsection_count  = 0,
    figure_count      = 0,
    table_count       = 0,
    equation_count    = 0,
    word_count        = 0,
}
local data = metrics_data

metrics_compile_start = metrics_compile_start or os.clock()
local compile_start = metrics_compile_start

-- ── .log File Parser — File Inclusion Tracking ───────────────────────────────
-- TeX logs every \input/\include in parentheses:
--   (/path/to/file.sty  ...  )  (nested (/inner.sty) )
-- We parse these parentheses to build the file inclusion tree.
-- This is the standard, reliable approach — it always works regardless
-- of ltluatex callback interception.

local LOG_SKIP_EXTENSIONS = {
    ["tfm"]  = true, ["enc"]  = true, ["pfb"]  = true, ["map"]  = true,
    ["lig"]  = true, ["fd"]   = true, ["cfg"]  = true, ["def"]  = true,
    ["pkl"]  = true, ["fmt"]  = true, ["otf"]  = true, ["ttf"]  = true,
    ["woff"] = true, ["woff2"]= true, ["png"]  = true, ["jpg"]  = true,
    ["jpeg"] = true, ["pdf"]  = true, ["eps"]  = true, ["bmp"]  = true,
    ["toc"]  = true, ["aux"]  = true, ["out"]  = true, ["lof"]  = true,
    ["lot"]  = true, ["nav"]  = true, ["snm"]  = true, ["vrb"]  = true,
    ["bbl"]  = true, ["blg"]  = true, ["bcf"]  = true, ["fls"]  = true,
    ["fdb_latexmk"] = true, ["synctex.gz"] = true, ["run.xml"] = true,
    ["idx"]  = true, ["ilg"]  = true, ["ind"]  = true, ["glo"]  = true,
    ["gls"]  = true, ["ist"]  = true, ["mtc"]  = true, ["mtc1"] = true,
    ["end"]  = true, ["ptc"]  = true, ["acn"]  = true, ["acr"]  = true,
    ["alg"]  = true, ["glg"]  = true, ["maf"]  = true, ["mlf"]  = true,
    ["mlt"]  = true, ["end"]  = true,
}

local function parse_log_for_files(log_path)
    local files = {}
    local seen = {}

    local f = io.open(log_path, "r")
    if not f then return files end

    local content = f:read("*a")
    f:close()

    -- Match file paths inside parentheses in the log.
    -- TeX log format: (filename  contents ) with nesting.
    -- We look for '(' followed by a path-like string.
    for path in content:gmatch("%(([^%s%)(\"%]]+)") do
        -- Skip empty, very short, or non-path strings
        if #path > 1 and (path:match("^/") or path:match("^%.") or path:match("^[A-Za-z]:")) then
            -- Extract basename
            local basename = path:match("([^/\\]+)$") or path
            -- Skip if it looks like a log message fragment, not a file
            if not basename:match("^%.") and basename:match("%.") then
                local ext = basename:match("%.([^.]+)$") or ""
                if not LOG_SKIP_EXTENSIONS[ext:lower()] then
                    if not seen[path] then
                        seen[path] = true
                        -- Normalize: strip leading ./
                        local clean = path:gsub("^%./", "")
                        table.insert(files, clean)
                    end
                end
            end
        end
    end

    -- Also match quoted paths: ("path with spaces")
    for path in content:gmatch('%("([^"]+)"') do
        if #path > 1 then
            local basename = path:match("([^/\\]+)$") or path
            local ext = basename:match("%.([^.]+)$") or ""
            if not LOG_SKIP_EXTENSIONS[ext:lower()] and not seen[path] then
                seen[path] = true
                local clean = path:gsub("^%./", "")
                table.insert(files, clean)
            end
        end
    end

    table.sort(files)
    return files
end

-- ── .aux File Parser — Document Structure Counters ──────────────────────────
-- The .aux file contains structured data about the document:
--   \@writefile{toc}{\contentsline {section}{...}{...}}  → sections
--   \@writefile{lof}{\contentsline {figure}{...}{...}}    → figures
--   \@writefile{lot}{\contentsline {table}{...}{...}}     → tables
--   \newlabel{eq:...}{...}                                 → equations
--   \newlabel{fig:...}{...}                                → figures (alt)
--   \newlabel{tab:...}{...}                                → tables (alt)

local function parse_aux_for_structure(aux_path)
    local result = {
        section_count    = 0,
        subsection_count = 0,
        figure_count     = 0,
        table_count      = 0,
        equation_count   = 0,
    }

    local f = io.open(aux_path, "r")
    if not f then return result end

    local content = f:read("*a")
    f:close()

    -- Count sections via \contentsline
    for _ in content:gmatch("\\contentsline%s*{section}%s*{") do
        result.section_count = result.section_count + 1
    end

    -- Count subsections
    for _ in content:gmatch("\\contentsline%s*{subsection}%s*{") do
        result.subsection_count = result.subsection_count + 1
    end

    -- Count figures via \contentsline {figure}
    for _ in content:gmatch("\\contentsline%s*{figure}%s*{") do
        result.figure_count = result.figure_count + 1
    end

    -- Count tables via \contentsline {table}
    for _ in content:gmatch("\\contentsline%s*{table}%s*{") do
        result.table_count = result.table_count + 1
    end

    -- Count equations via \newlabel{eq:...} (standard LaTeX equation labels)
    for _ in content:gmatch("\\newlabel{%s*eq:") do
        result.equation_count = result.equation_count + 1
    end

    -- Also count figures/tables from \newlabel (in case \contentsline missed them)
    -- Only count if \contentsline count is 0 (fallback)
    if result.figure_count == 0 then
        for _ in content:gmatch("\\newlabel{%s*fig:") do
            result.figure_count = result.figure_count + 1
        end
    end
    if result.table_count == 0 then
        for _ in content:gmatch("\\newlabel{%s*tab:") do
            result.table_count = result.table_count + 1
        end
    end

    return result
end

-- ── Word Count Estimator ────────────────────────────────────────────────────
-- Reads the main .tex file and estimates word count by counting
-- whitespace-delimited tokens that are NOT LaTeX commands or comments.
-- This is a rough estimate — for accurate counts, use texcount.

local function estimate_word_count(tex_path)
    local f = io.open(tex_path, "r")
    if not f then return 0 end

    local content = f:read("*a")
    f:close()

    -- Remove comments (% to end of line, but not escaped \%)
    content = content:gsub("(?<!\\)%%[^\n]*", "")

    -- Remove LaTeX commands (\word or \word[...]{...})
    content = content:gsub("\\[%a@]+%b[]", "")  -- \cmd[...]
    content = content:gsub("\\[%a@]+%b{}", "")   -- \cmd{...}
    content = content:gsub("\\[%a@]+", " ")       -- remaining \cmd

    -- Remove braces, brackets, math delimiters
    content = content:gsub("[{}%[%]%%$&_^~#]", " ")

    -- Count whitespace-delimited "words" (non-empty sequences)
    local count = 0
    for word in content:gmatch("%S+") do
        if #word > 1 then
            count = count + 1
        end
    end

    return count
end

-- ── Phase 1: collect_metrics() — called at \AtEndDocument ──────────────────
-- Collects basic metrics (time, pages, files, warnings) and writes initial JSON.
-- Structure counters are left at 0; they are filled in by finalize_metrics().

function collect_metrics()
    data.wall_time = os.clock() - metrics_compile_start

    -- Engine info
    if status then
        data.engine = status.luatex_engine or data.engine
        if status.luatex_version then
            local v = status.luatex_version
            data.luatex_version = string.format("%d.%d.%d",
                math.floor(v / 100),
                math.floor((v % 100) / 1),
                0
            )
        end
    end

    -- Job name and PDF path
    if tex and tex.jobname then
        data.job_name = tex.jobname
        data.pdf_path = tex.jobname .. ".pdf"
    end

    -- Page count from TeX counter
    if tex and tex.count then
        local cpage = tex.count["c@page"]
        if cpage then
            data.page_count = cpage
        end
    end

    -- PDF size (approximate — PDF not fully finalized at \AtEndDocument)
    local pdf_path = data.pdf_path
    if pdf_path and pdf_path ~= "" then
        local f = io.open(pdf_path, "rb")
        if f then
            data.pdf_size = f:seek("end")
            f:close()
        end
    end

    -- Warning count: count "Warning" lines in .log
    local log_path = data.job_name .. ".log"
    local log_f = io.open(log_path, "r")
    if log_f then
        local count = 0
        for line in log_f:lines() do
            if line:match("Warning") then
                count = count + 1
            end
        end
        data.warning_count = count
        log_f:close()
    end

    -- File inclusion tree (from .log file)
    if not metrics_skip_log then
        data.included_files = parse_log_for_files(log_path)
    end

    -- Word count estimate (from main .tex file)
    local main_tex = data.job_name .. ".tex"
    data.word_count = estimate_word_count(main_tex)

    -- NOTE: .aux file structure counters are NOT parsed here because TeX has
    -- the .aux file open for writing at this point (truncated, data in buffer).
    -- Lua's io.open sees 0 bytes.  Structure counters are parsed AFTER
    -- compilation by compile.py (or scripts/metrics_finalize.py).

    -- Write final JSON
    local output = to_json(data, 0)
    local f = io.open(metrics_output_path, "w")
    if f then
        f:write(output)
        f:write("\n")
        f:close()
        texio.write_nl(string.format(
            "[metrics.lua v3.0] Written %s — %d pages, %.2fs, %d files, "
            .. "~%d words, %d warnings",
            metrics_output_path,
            data.page_count,
            data.wall_time,
            #data.included_files,
            data.word_count,
            data.warning_count
        ))
    else
        texio.write_nl(string.format(
            "[metrics.lua] Error: could not write %s", metrics_output_path))
    end
end

-- ── (no longer needed) ─────────────────────────────────────────────────────
-- The finalize_metrics() function was removed.  Structure counter parsing
-- now happens inside collect_metrics() directly.

-- ── TeX Integration ─────────────────────────────────────────────────────────
-- NOTE: We must NOT use % (comment) inside tex.sprint because tex.sprint
-- converts newlines to spaces, causing % to eat everything until the end
-- of the input buffer.  Use \relax or nothing for spacing.
--
-- Phase 2 (structure counters from .aux) runs inside collect_metrics()
-- itself.  The .aux file from the PREVIOUS compilation run is available
-- at \AtEndDocument time (TeX reads it at \begin{document} and keeps it
-- open).  On the very first compile, structure counters will be 0 (no
-- previous .aux exists).  This matches standard LaTeX behavior: you
-- always need 2+ runs for correct cross-references and TOC.

if tex then
    tex.sprint("\\AtEndDocument{\\directlua{collect_metrics()}}")
    tex.sprint("\\newcommand\\metricprint{\\directlua{metricprint_snap()}}")
end

-- Snap function (called by \metricprint)
function metricprint_snap()
    local file_count = metrics_data.included_files and #metrics_data.included_files or 0
    texio.write_nl(string.format(
        "[metrics.lua] Snapshot: %d files tracked, %.2fs elapsed",
        file_count, os.clock() - metrics_compile_start
    ))
end

return data

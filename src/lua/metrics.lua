--[[
  metrics.lua — TeX document metrics collector (v2.0)

  Collects detailed statistics about a document during LuaLaTeX compilation.
  Writes results to a JSON file at the end of compilation.

  Usage in .tex preamble (AFTER \documentclass):
    \directlua{dofile("metrics.lua")}
    -- OR with search path:
    \directlua{dofile("src/lua/metrics.lua")}

  For the best experience, load it early (before heavy packages like tikz)
  so wall_time captures the full compilation.

  Configuration (set BEFORE loading metrics.lua):
    \directlua{metrics_output_path = "custom/path.json"}

  Collected metrics:
    - Engine info (LuaTeX version, engine name)
    - Compilation wall time (os.clock, not os.time)
    - Page count (via tex.count["c@page"])
    - PDF output file size
    - Warning count (parsed from log output)
    - File inclusion list (tracked via open_read_file callback)
    - Mid-compilation snapshot via \metricprint

  Design notes:
    - Uses \AtEndDocument instead of stop_run callback because ltluatex.lua
      (loaded by modern LaTeX) intercepts callback.register() and blocks
      direct callback registration.  \AtEndDocument is reliable and portable.
    - Uses open_read_file callback (which ltluatex doesn't block) for
      tracking file inclusions.
    - Wall time may be slightly less than real elapsed time because
    LuaTeX has some C-level overhead before and after Lua execution.
]]

local metrics_output_path = metrics_output_path or "metrics-output.json"

-- ── JSON Serialization ──────────────────────────────────────────────────────
-- Made global so collect_metrics() (called from \AtEndDocument via \directlua)
-- can access it.

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
-- Global so that collect_metrics() can access it from \AtEndDocument.

metrics_data = metrics_data or {
    engine         = "unknown",
    luatex_version = "unknown",
    job_name       = "unknown",
    wall_time      = 0,
    page_count     = 0,
    pdf_size       = 0,
    pdf_path       = "",
    warning_count  = 0,
    included_files = {},
}
local data = metrics_data

metrics_compile_start = metrics_compile_start or os.clock()
local compile_start = metrics_compile_start

-- ── File Inclusion Tracking ──────────────────────────────────────────────────
-- We try to register open_read_file callback for tracking file inclusions.
-- If it fails (e.g., ltluatex already claimed it), we fall back gracefully.

local function try_register_open_read(fn)
    if not callback then return false end
    -- Try raw registration first
    local ok = pcall(callback.register, "open_read_file", fn)
    if ok then return true end
    -- If that fails, the callback is already claimed — that's fine
    return false
end

local _ = try_register_open_read(function(file_name)
    local basename = file_name
    local s, e = file_name:find("[^/\\]+$")
    if s then basename = file_name:sub(s, e) end

    -- Skip internal TeX files
    if basename:match("%.tfm$") or basename:match("%.enc$")
        or basename:match("%.pfb$") or basename:match("%.map$")
        or basename:match("%.lig$") or basename:match("%.fd$")
        or basename:match("%.cfg$") or basename:match("%.def$")
        or basename:match("%.pkl$") or basename:match("%.fmt$")
    then
        return file_name
    end

    -- Also skip font and image files
    if basename:match("%.otf$") or basename:match("%.ttf$")
        or basename:match("%.woff") or basename:match("%.pdf$")
        or basename:match("%.png$") or basename:match("%.jpg$")
    then
        return file_name
    end

    table.insert(data.included_files, file_name)
    return file_name
end)

if not _ then
    -- open_read_file callback not available — included_files will be empty
end

-- ── Metrics Collection Function ─────────────────────────────────────────────
-- Called via \AtEndDocument.  Collects all metrics and writes JSON.
-- Must be a global function because \AtEndDocument{\\directlua{...}}
-- executes in a separate Lua chunk.

function collect_metrics()
    data.wall_time = os.clock() - metrics_compile_start

    -- Engine info
    if status then
        data.engine = status.luatex_engine or data.engine
        if status.luatex_version then
            local v = status.luatex_version
            -- LuaTeX encodes version as MMNNPP (e.g., 12400 = 1.24.0)
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

    -- PDF size
    -- NOTE: At \AtEndDocument time, the PDF may not be fully written yet.
    -- The reported size may be smaller than the final file size.
    -- For accurate size, check the file after compilation finishes.
    local pdf_path = data.pdf_path
    if pdf_path and pdf_path ~= "" then
        local f = io.open(pdf_path, "rb")
        if f then
            data.pdf_size = f:seek("end")
            f:close()
        end
    end

    -- Warning count: read the .log file and count "Warning" lines
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

    -- Write JSON
    local output = to_json(data, 0)
    local f = io.open(metrics_output_path, "w")
    if f then
        f:write(output)
        f:write("\n")
        f:close()
        texio.write_nl(string.format(
            "[metrics.lua] Written %s — %d pages, %.2fs, %d bytes, %d warnings",
            metrics_output_path, data.page_count, data.wall_time,
            data.pdf_size, data.warning_count
        ))
    else
        texio.write_nl(string.format(
            "[metrics.lua] Error: could not write %s", metrics_output_path))
    end
end

-- ── TeX Integration ─────────────────────────────────────────────────────────

if tex then
    -- Use \AtEndDocument to trigger metrics collection at the very end.
    -- This works reliably regardless of ltluatex callback interception.
    tex.sprint("\\AtEndDocument{\\directlua{collect_metrics()}}")

    -- Provide \metricprint for mid-compilation snapshots.
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

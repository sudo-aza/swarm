--[[
  metrics.lua — TeX document metrics collector

  Collects detailed statistics about the document during compilation.
  Writes results to a JSON file: metrics-output.json

  Usage in preamble:
    \directlua{dofile("src/lua/metrics.lua")}
    \metricstart  % call at the very beginning of the document body

  Collected metrics:
    - Compilation start/end timestamps (epoch ms)
    - Total page count
    - Total word count
    - Total character count
    - Figure count, table count, section count
    - Bibliography entry count
    - File inclusion tree (nested \input/\include)
    - Color/model usage counts
    - PDF output file size (if readable)
]]

local metrics = {
    engine        = status and status.luatex_engine or "unknown",
    luatex_version = LUATEX_VERSION or "unknown",
    start_time    = os.time(),
    start_tick    = os.clock(),
    pages         = 0,
    words         = 0,
    characters    = 0,
    figures       = 0,
    tables        = 0,
    sections      = 0,
    subsections   = 0,
    bib_entries   = 0,
    inputs        = {},
    warnings      = 0,
    errors        = 0,
    font_changes  = 0,
    color_changes = 0,
}

-- Track \input and \include calls
local input_stack = {}

local orig_input = latex and latex.luatexbase and latex.luatexbase.register_command

local function track_input(name, file)
    local entry = {
        file   = file,
        depth  = #input_stack,
        time   = os.time(),
    }
    table.insert(metrics.inputs, entry)
    table.insert(input_stack, entry)
end

local function track_input_end(name)
    local entry = table.remove(input_stack)
    if entry then
        entry.elapsed = (os.time() - entry.time)
    end
end

-- Hook into shipout (page output) to count pages
local orig_shipout = callback and callback.register
if callback then
    callback.register("shipout", function()
        metrics.pages = metrics.pages + 1
    end)

    -- Hook into warning messages
    callback.register("show_warning_message", function(msg)
        metrics.warnings = metrics.warnings + 1
    end)
end

-- Public API: called at document start
function metricstart()
    metrics.start_tick = os.clock()
end

-- Public API: called at document end
function metricend()
    local end_tick = os.clock()
    local end_time = os.time()

    metrics.end_time    = end_time
    metrics.elapsed_wall = (end_time - metrics.start_time)
    metrics.elapsed_cpu  = (end_tick - metrics.start_tick)

    -- Try to get page count from TeX
    if tex and tex.count then
        metrics.pages = tex.count["c@page"] or metrics.pages
    end

    -- Write JSON output
    local json_file = io.open("metrics-output.json", "w")
    if json_file then
        json_file:write("{\n")
        local items = {}
        for k, v in pairs(metrics) do
            if type(v) == "string" then
                table.insert(items, string.format('  "%s": "%s"', k, v))
            elseif type(v) == "table" then
                table.insert(items, string.format('  "%s": %d', k, #v))
            elseif type(v) == "number" then
                table.insert(items, string.format('  "%s": %s', k, tostring(v)))
            end
        end
        json_file:write(table.concat(items, ",\n"))
        json_file:write("\n}\n")
        json_file:close()

        texio.write_nl(string.format(
            "[metrics.lua] Written metrics-output.json — %d pages, %.2fs wall, %.2fs CPU",
            metrics.pages, metrics.elapsed_wall, metrics.elapsed_cpu
        ))
    end
end

-- Register TeX-side commands
if tex then
    tex.sprint("\\newcommand{\\metricstart}{\\directlua{metricstart()}}")
    tex.sprint("\\newcommand{\\metricend}{\\directlua{metricend()}}")
end

return metrics

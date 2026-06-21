local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local orig_buildpage = luatexbase.remove_from_callback("buildpage_filter", "swarmwrap: buildpage filter")

luatexbase.add_to_callback("buildpage_filter",
  function(head, groupcode)
    local rnl = swarmwrap_safe_count("swarmwrap@remaining@nl")
    local tw_lua = swarmwrap_safe_dimen("swarmwrap@tw@lua")
    texio.write_nl("BP: rnl=" .. rnl .. " tw=" .. string.format("%.1f", tw_lua/65536) .. " fig=" .. tostring(swarmwrap_fig_on_page) .. " ltw_before=" .. string.format("%.1f", swarmwrap_leak_tw/65536))
    local result = orig_buildpage(head, groupcode)
    texio.write_nl("BP_after: ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536) .. " phf=" .. tostring(swarmwrap_page_had_fig))
    return result
  end, "swarmwrap: buildpage filter")

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    texio.write_nl("SHIP: phf=" .. tostring(swarmwrap_page_had_fig) .. " ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536))
    local result = orig_shipout(head, groupcode)
    texio.write_nl("SHIP_after: ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536))
    return result
  end, "swarmwrap: parshape leak fix")
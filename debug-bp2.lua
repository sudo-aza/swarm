local orig_buildpage = luatexbase.remove_from_callback("buildpage_filter", "swarmwrap: buildpage filter")
local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local page_num = 0

luatexbase.add_to_callback("buildpage_filter",
  function(head, groupcode)
    page_num = page_num + 1
    texio.write_nl("BP[" .. page_num .. "]: fig_on_page=" .. tostring(swarmwrap_fig_on_page) .. " rnl=" .. swarmwrap_safe_count("swarmwrap@remaining@nl") .. " leak_tw=" .. tostring(swarmwrap_leak_tw > 0))
    local result = orig_buildpage(head, groupcode)
    texio.write_nl("BP[" .. page_num .. "]_AFTER: page_had_fig=" .. tostring(swarmwrap_page_had_fig) .. " fig_on_page=" .. tostring(swarmwrap_fig_on_page) .. " leak_tw=" .. tostring(swarmwrap_leak_tw > 0))
    return result
  end, "swarmwrap: buildpage filter")

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    texio.write_nl("SHIP[" .. page_num .. "]: page_had_fig=" .. tostring(swarmwrap_page_had_fig) .. " leak_tw=" .. tostring(swarmwrap_leak_tw > 0))
    local result = orig_shipout(head, groupcode)
    texio.write_nl("SHIP[" .. page_num .. "]_AFTER: leak_tw=" .. tostring(swarmwrap_leak_tw > 0))
    return result
  end, "swarmwrap: parshape leak fix")
local orig_postlb = luatexbase.remove_from_callback("post_linebreak_filter", "swarmwrap: penalty at parshape boundary")
local orig_buildpage = luatexbase.remove_from_callback("buildpage_filter", "swarmwrap: buildpage filter")
local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local para_num = 0

luatexbase.add_to_callback("post_linebreak_filter",
  function(head, groupcode)
    para_num = para_num + 1
    local total = 0
    local narrow = 0
    local narrow_widths = {}
    local first_text = ""
    local current = head
    while current do
      if current.id == 0 then
        total = total + 1
        local lw = current.width / 65536.0
        if lw < 300 and lw > 0 then
          narrow = narrow + 1
          narrow_widths[#narrow_widths + 1] = string.format("%.1f", lw)
        end
        if first_text == "" then
          for n in node.traverse(current) do
            if n.id == 37 then  -- glyph
              local char = unicode.utf8.char(n.char)
              if char ~= "" then
                first_text = string.sub(char .. node.traverse(current.head).char and "..." or "", 1, 30)
                break
              end
            end
          end
          -- simpler: just get first glyph
          local inn = current.head
          while inn do
            if inn.id == 37 then
              first_text = unicode.utf8.char(inn.char)
              break
            end
            inn = inn.next
          end
        end
      end
      current = current.next
    end
    local gw_str = tostring(swarmwrap_ghost_widen)
    local gtw_str = string.format("%.1f", swarmwrap_ghost_tw / 65536.0)
    local widths_str = table.concat(narrow_widths, ",")
    texio.write_nl("PLB[" .. para_num .. "]: total=" .. total .. " narrow=" .. narrow .. " gw=" .. gw_str .. " gtw=" .. gtw_str .. " w={" .. widths_str .. "} text='" .. first_text .. "'")
    return orig_postlb(head, groupcode)
  end, "swarmwrap: penalty at parshape boundary")

luatexbase.add_to_callback("buildpage_filter",
  function(head, groupcode)
    local rnl = swarmwrap_safe_count("swarmwrap@remaining@nl")
    local tw_lua = swarmwrap_safe_dimen("swarmwrap@tw@lua")
    texio.write_nl("BP: rnl=" .. rnl .. " tw=" .. string.format("%.1f", tw_lua/65536) .. " fig=" .. tostring(swarmwrap_fig_on_page) .. " gw=" .. tostring(swarmwrap_ghost_widen) .. " ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536))
    local result = orig_buildpage(head, groupcode)
    texio.write_nl("BP_after: gw=" .. tostring(swarmwrap_ghost_widen) .. " ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536) .. " phf=" .. tostring(swarmwrap_page_had_fig))
    return result
  end, "swarmwrap: buildpage filter")

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    texio.write_nl("SHIP: phf=" .. tostring(swarmwrap_page_had_fig) .. " ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536) .. " gw=" .. tostring(swarmwrap_ghost_widen))
    local result = orig_shipout(head, groupcode)
    texio.write_nl("SHIP_after: ltw=" .. string.format("%.1f", swarmwrap_leak_tw/65536))
    return result
  end, "swarmwrap: parshape leak fix")
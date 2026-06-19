local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    texio.write_nl("PRESHIP: phf=" .. tostring(swarmwrap_page_had_fig) .. " ltw=" .. tostring(swarmwrap_leak_tw > 0))
    if not swarmwrap_page_had_fig and swarmwrap_leak_tw > 0 then
      local page = head.head
      local fullw = swarmwrap_safe_dimen("textwidth")
      local narrow_max = swarmwrap_leak_tw + 30.0 * 65536
      local hbox_count = 0
      local narrow_count = 0
      local function count_recursive(n)
        while n do
          if n.id == 0 then
            hbox_count = hbox_count + 1
            local w = n.width
            if w <= narrow_max and w > 20 * 65536 and w < fullw - 10 * 65536 then
              narrow_count = narrow_count + 1
            end
          elseif n.id == 1 then
            count_recursive(n.head)
          end
          n = n.next
        end
      end
      count_recursive(page)
      texio.write_nl("PRESHIP_DETAIL: hboxes=" .. hbox_count .. " narrow=" .. narrow_count .. " fullw=" .. tostring(fullw) .. " nmax=" .. tostring(narrow_max))
    end
    local result = orig_shipout(head, groupcode)
    return result
  end, "swarmwrap: parshape leak fix")
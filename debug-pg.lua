local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local page_idx = 0

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    page_idx = page_idx + 1
    if not swarmwrap_page_had_fig and swarmwrap_leak_tw > 0 then
      local page = head.head
      local total_h = 0
      local total_v = 0
      local narrow_h = 0
      local fullw = swarmwrap_safe_dimen("textwidth")
      local nmax = swarmwrap_leak_tw + 30.0 * 65536
      local function inspect(n, depth)
        while n do
          if n.id == 0 then
            total_h = total_h + 1
            local w = n.width
            if w <= nmax and w > 20 * 65536 and w < fullw - 10 * 65536 then
              narrow_h = narrow_h + 1
            end
          elseif n.id == 1 then
            total_v = total_v + 1
            if depth < 4 then
              inspect(n.head, depth + 1)
            end
          end
          n = n.next
        end
      end
      inspect(page, 0)
      texio.write_nl("PG" .. page_idx .. ": v=" .. total_v .. " h=" .. total_h .. " narrow=" .. narrow_h)
    end
    local result = orig_shipout(head, groupcode)
    return result
  end, "swarmwrap: parshape leak fix")
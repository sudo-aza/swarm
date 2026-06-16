local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local page_idx = 0

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    page_idx = page_idx + 1
    if not swarmwrap_page_had_fig and swarmwrap_leak_tw > 0 then
      local page = head.head
      local fullw = swarmwrap_safe_dimen("textwidth")
      local nmax = swarmwrap_leak_tw + 30.0 * 65536
      local narrow_h = 0
      local widths = {}
      local function inspect(n, depth)
        while n do
          if n.id == 0 then
            local w = n.width
            if w <= nmax and w > 20 * 65536 and w < fullw - 10 * 65536 then
              narrow_h = narrow_h + 1
              widths[#widths + 1] = math.floor(w / 655.36) / 100
            end
          elseif n.id == 1 then
            if depth < 4 then
              inspect(n.head, depth + 1)
            end
          end
          n = n.next
        end
      end
      inspect(page, 0)
      local wstr = table.concat(widths, ",")
      texio.write_nl("PG" .. page_idx .. ": fullw=" .. math.floor(fullw / 655.36) / 100 .. " nmax=" .. math.floor(nmax / 655.36) / 100 .. " narrow=" .. narrow_h .. " w={" .. wstr .. "}")
    end
    local result = orig_shipout(head, groupcode)
    return result
  end, "swarmwrap: parshape leak fix")
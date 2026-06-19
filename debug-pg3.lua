local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")
local page_idx = 0

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    page_idx = page_idx + 1
    if not swarmwrap_page_had_fig and swarmwrap_leak_tw > 0 then
      local page = head.head
      local depth_counts = {0, 0, 0, 0, 0}
      local h_widths = {}
      local function inspect(n, depth)
        while n do
          if depth <= 4 then
            depth_counts[depth + 1] = depth_counts[depth + 1] + 1
          end
          if n.id == 0 then
            local w = n.width
            if #h_widths < 5 then
              h_widths[#h_widths + 1] = math.floor(w / 65.536) / 1000
            end
          end
          if n.id == 1 and depth < 4 then
            inspect(n.head, depth + 1)
          end
          n = n.next
        end
      end
      inspect(page, 0)
      local dc = {}
      for i, c in ipairs(depth_counts) do
        dc[#dc + 1] = "d" .. (i-1) .. "=" .. c
      end
      local ws = {}
      for i, w in ipairs(h_widths) do
        ws[#ws + 1] = tostring(w)
      end
      texio.write_nl("PG" .. page_idx .. ": " .. table.concat(dc, " ") .. " hw={" .. table.concat(ws, ",") .. "}")
    end
    local result = orig_shipout(head, groupcode)
    return result
  end, "swarmwrap: parshape leak fix")
local orig_shipout = luatexbase.remove_from_callback("pre_shipout_filter", "swarmwrap: parshape leak fix")

luatexbase.add_to_callback("pre_shipout_filter",
  function(head, groupcode)
    if not swarmwrap_page_had_fig and swarmwrap_leak_tw > 0 then
      local page = head.head
      local top_counts = {}
      local function count_nodes(n, depth)
        while n do
          local id_name = node.type(n.id)
          top_counts[id_name] = (top_counts[id_name] or 0) + 1
          if depth < 3 and n.id == 1 and n.head then
            count_nodes(n.head, depth + 1)
          end
          n = n.next
        end
      end
      count_nodes(page, 0)
      local parts = {}
      for k, v in pairs(top_counts) do
        parts[#parts + 1] = k .. "=" .. v
      end
      texio.write_nl("PAGE_NODES[" .. table.concat(parts, ", ") .. "]")
    end
    local result = orig_shipout(head, groupcode)
    return result
  end, "swarmwrap: parshape leak fix")
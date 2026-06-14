local orig_postlb = luatexbase.remove_from_callback("post_linebreak_filter", "swarmwrap: penalty at parshape boundary")
local widen_count = 0

function swarmwrap_post_lb(head, groupcode)
  if swarmwrap_ghost_widen then
    local lw_val = swarmwrap_safe_dimen("swarmwrap@lw@saved")
    local ghost_tw = swarmwrap_ghost_tw
    local tol = 15.0
    local narrow_max = (ghost_tw / 65536.0) + tol
    local orig_count = widen_count
    local current = head
    while current do
      if current.id == 0 then
        local lw = current.width / 65536.0
        if lw <= narrow_max and lw > 0 then
          current.width = lw_val
          local inner_head = current.head
          if inner_head then
            local inner_last = node.tail(inner_head)
            local fil = node.new(node.id("glue"))
            fil.stretch = 65536
            fil.stretch_order = 2
            if inner_last then
              node.insert_after(inner_head, inner_last, fil)
            else
              current.head = fil
            end
            widen_count = widen_count + 1
          end
        end
      end
      current = current.next
    end
    swarmwrap_ghost_widen = false
    texio.write_nl("GW: widened " .. (widen_count - orig_count) .. " lines gtw=" .. tostring(math.floor(ghost_tw / 655.36) / 100) .. " lw=" .. tostring(math.floor(lw_val / 655.36) / 100))
    return head
  end
  return orig_postlb(head, groupcode)
end

luatexbase.add_to_callback("post_linebreak_filter",
  function(head, groupcode)
    local ok, result = pcall(swarmwrap_post_lb, head, groupcode)
    if ok then return result end
    return head
  end, "swarmwrap: penalty at parshape boundary")
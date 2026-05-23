-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.28: Penalty insertion only. Line widening removed — full-width
-- reset is now handled by a trailing parshape entry in the .sty file
-- (nl narrow entries + 1 full-width entry). The height padding was
-- increased from 4pt to baselineskip to ensure the figure ends before
-- the full-width line starts, preventing body-text overlaps.

local debug_mode = false

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0

  -- Penalty insertion at parshape boundary
  if tw_sp > 0 then
    local penalty_val = tex.count["swarmwrap@penalty"]
    if penalty_val > 0 then
      local last_narrow = nil
      local current = head
      while current do
        if current.id == 0 then
          local lw = current.width / 65536.0
          if lw <= tw_val + 3.0 and lw > 0 then
            last_narrow = current
          end
        end
        current = current.next
      end
      if last_narrow then
        local p = node.new(node.id("penalty"))
        p.penalty = penalty_val
        node.insert_after(head, last_narrow, p)
      end
    end
  end
  return head
end

texio.write_nl("swarmwrap: callback v3.28 loaded (penalty only)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: penalty")
texio.write_nl("swarmwrap: callback registered successfully")

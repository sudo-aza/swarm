-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.24: Removed line counting from post_linebreak_filter. Multi-paragraph
-- parshape extension now uses synchronous vertical-space tracking in the
-- TeX-side \par patch (see swarmwrap.sty v3.24 changelog).
-- This callback is now ONLY used for penalty insertion at the parshape
-- boundary (discouraging page breaks that cause ghost narrowing).

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0
  local tol = 3.0
  local narrow_width_max = tw_val + tol

  -- Penalty insertion at parshape boundary
  if tw_sp > 0 then
    local penalty_val = tex.count["swarmwrap@penalty"]
    if penalty_val > 0 then
      local last_narrow = nil
      local current = head
      while current do
        if current.id == 0 then
          local lw = current.width / 65536.0
          if lw <= narrow_width_max and lw > 0 then
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

texio.write_nl("swarmwrap: callback v3.24 loaded, registering post_linebreak_filter")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: penalty at parshape boundary")
texio.write_nl("swarmwrap: callback registered successfully")

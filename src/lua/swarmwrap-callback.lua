-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.22: Fix remaining counter — count only narrow lines beside the figure.
-- Previous versions counted ALL lines (including full-width trailing lines),
-- which over-decremented remaining on the first paragraph, preventing the
-- \par patch from extending parshape to subsequent paragraphs.

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0
  local tol = 3.0
  local narrow_width_max = tw_val + tol

  -- Read the TeX-side remaining counter
  local rem = tex.count["swarmwrap@remaining"]

  if rem > 0 and tw_sp > 0 then
    -- Count only NARROW lines (lines beside the figure).
    -- Full-width trailing lines (past the figure) don't consume figure
    -- vertical space and should NOT decrement remaining.
    local narrow_count = 0
    local cur = head
    while cur do
      if cur.id == 0 then
        local lw = cur.width / 65536.0
        if lw <= narrow_width_max and lw > 0 then
          narrow_count = narrow_count + 1
        end
      end
      cur = cur.next
    end
    -- Only decrement by narrow lines (capped at remaining).
    local new_rem = math.max(0, rem - narrow_count)
    tex.count["swarmwrap@remaining"] = new_rem
  end

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

texio.write_nl("swarmwrap: callback v3.22 loaded, registering post_linebreak_filter")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: multi-para + penalty at parshape boundary")
texio.write_nl("swarmwrap: callback registered successfully")

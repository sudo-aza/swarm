-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.29: Line widening + penalty insertion.
-- After N narrow hboxes (beside the figure), subsequent hboxes are
-- widened to full linewidth. This fixes ghost-narrowing without using
-- a trailing parshape entry, which caused 47 body-text overlaps on
-- the 50-figure stress test (full-width text overlapping the next
-- session's figure). The baselineskip padding in swarmwrap.sty
-- ensures at least one line of clearance between the figure bottom
-- and the first widened line.

local debug_mode = false

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0

  -- Only process if wrapping is active (tw > 0)
  if tw_sp <= 0 then
    return head
  end

  local nl = tex.count["swarmwrap@nl@lua"]
  local linewidth = tex.dimen["linewidth"] / 65536.0
  local penalty_val = tex.count["swarmwrap@penalty"]

  -- Phase 1: Count hboxes and widen those after position nl
  if nl > 0 then
    local hbox_count = 0
    local current = head
    while current do
      if current.id == 0 then -- hbox
        hbox_count = hbox_count + 1
        if hbox_count > nl then
          -- This hbox is past the narrow zone. Widen to full linewidth.
          local lw = current.width / 65536.0
          if lw < linewidth - 5.0 then
            current.width = tex.dimen["linewidth"]
          end
        end
      end
      current = current.next
    end
  end

  -- Phase 2: Penalty insertion at parshape boundary
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

  return head
end

texio.write_nl("swarmwrap: callback v3.29 loaded (widening + penalty)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: widen+penalty")
texio.write_nl("swarmwrap: callback registered successfully")

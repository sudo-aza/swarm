-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.30: Penalty insertion only (hbox widening removed).
--
-- v3.29's hbox widening (setting current.width = tex.dimen["linewidth"]
-- for hboxes after position nl) did NOT modify actual text glyph positions.
-- QA verified via PyMuPDF that text spans remained at 259.7pt (43.6%
-- page width) — only the hbox reference width changed, not the content.
--
-- The ghost-narrowing fix is now handled by the trailing full-width
-- parshape entry (0pt \linewidth) in swarmwrap.sty. TeX repeats
-- the last parshape entry for all subsequent lines, so text after
-- nl narrow lines automatically resets to full page width.
--
-- This callback retains only the penalty insertion at the narrow/full-width
-- boundary, discouraging page breaks that would cause continuation-page
-- ghost narrowing.

local debug_mode = false

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0

  -- Only process if wrapping is active (tw > 0)
  if tw_sp <= 0 then
    return head
  end

  local linewidth = tex.dimen["linewidth"] / 65536.0
  local penalty_val = tex.count["swarmwrap@penalty"]

  -- Penalty insertion at parshape boundary (narrow → full-width)
  -- Insert a penalty after the last narrow hbox to discourage page breaks
  -- at the transition point where ghost narrowing would occur.
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

texio.write_nl("swarmwrap: callback v3.30 loaded (penalty only)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: penalty")
texio.write_nl("swarmwrap: callback registered successfully")

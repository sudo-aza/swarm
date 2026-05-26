-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.44: Fix visible content height — use raw box height (Task #190).
--   v3.43 subtracted strutbox.height + strutbox.depth from box.height +
--   box.depth. This was WRONG for [t]-minipages with tall figures: the
--   strut is shorter than the rule, so box.height = rule height (not
--   strut height). Subtracting strut_h removed a full baselineskip of
--   actual visible content (caption area), causing caption-text overlap.
--   Debug node traversal confirmed: strut_h = 13.60pt for LM 11pt, but
--   box.height already equals rule height (not strut height). So the
--   subtraction over-counted by 13.6pt, making visible height too small.
--   v3.44 uses raw box.height + box.depth, which covers the full
--   figure + \abovecaptionskip + caption block. The parshape loop's
--   ceil provides at most 1 line of excess (~13.6pt), which is the
--   minimum possible overhead for alignment to baselineskip boundaries.
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
-- This callback retains the penalty insertion at the narrow/full-width
-- boundary, discouraging page breaks that would cause continuation-page
-- ghost narrowing.

local debug_mode = false

-- ── Visible content height measurement (v3.44) ──────────────────
-- Uses raw box.height + box.depth as the visible content height.
-- This is the tightest measurement that guarantees the narrow text
-- zone covers the entire figure + caption block without overlap.
--
-- Why NOT subtract strut_h:
--   For [t]-minipages with tall figures (rule > strut), box.height
--   = rule height (strut is hidden behind the taller rule). So
--   box.height already has NO strut overhead to subtract. Subtracting
--   strut_h removes caption content instead, causing overlap.
--
-- Why NOT use max_rule_height (v3.42):
--   That only measured the colored rectangle, missing the caption
--   entirely. Body text overlapped caption on all 50 figures.
--
-- Trade-off:
--   Raw box height includes \abovecaptionskip (10pt of blank space
--   between figure and caption). This adds ~1 extra narrow line per
--   figure compared to an ideal measurement. But it's the ONLY
--   measurement that is both safe (no overlap) and font-independent
--   (doesn't depend on strut dimensions).

function swarmwrap_measure_visible_height(box_reg)
  local box = tex.box[box_reg]
  if not box then
    if debug_mode then
      texio.write_nl("swarmwrap DEBUG: box[" .. box_reg .. "] is nil")
    end
    return 0
  end

  local bs = tex.skip["baselineskip"].width
  local raw_height = box.height + box.depth

  -- Use raw box height — covers full figure + caption block.
  -- The parshape loop's ceil adds at most 1 line of overhead.
  local visible = raw_height

  -- Minimum: at least 1 baselineskip
  if visible < bs then
    visible = bs
  end

  if debug_mode then
    local strutbox = tex.box["strutbox"]
    local strut_h = strutbox.height + strutbox.depth
    texio.write_nl(string.format(
      "swarmwrap v3.44: box ht=%.2f dp=%.2f raw=%.2f strut=%.2f visible=%.2f bs=%.1f",
      box.height / 65536.0,
      box.depth / 65536.0,
      raw_height / 65536.0,
      strut_h / 65536.0,
      visible / 65536.0,
      bs / 65536.0))
  end

  return visible
end

-- ── Post-linebreak filter (v3.30) ────────────────────────────────────

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

texio.write_nl("swarmwrap: callback v3.44 loaded (penalty + raw box height)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: penalty")
texio.write_nl("swarmwrap: callback registered successfully")

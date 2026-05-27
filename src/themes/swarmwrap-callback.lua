-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.41: Added visible content height measurement for parshape.
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

-- ── Visible content height measurement (v3.41, Task #190) ──────────
-- Measures the actual visible content height of a box by traversing
-- its node list and summing the heights of rule nodes (colored
-- rectangles, images) and glyph nodes (caption text).
-- Glue, kern, penalty, and strut nodes are skipped — they represent
-- spacing overhead that inflates ht+dp but doesn't correspond to
-- visible figure content.
--
-- Returns the height in scaled points (1pt = 65536sp).

function find_max_rule_height(head)
  -- Recursively find the maximum rule height in a node list.
  -- Rules represent visible colored rectangles (the actual figure).
  local max_h = 0
  for n in node.traverse(head) do
    if n.id == node.id("rule") then
      local h = n.height + n.depth
      if h > max_h then max_h = h end
    elseif n.id == node.id("hlist") or n.id == node.id("vlist") then
      if n.head then
        local sub = find_max_rule_height(n.head)
        if sub > max_h then max_h = sub end
      end
    end
  end
  return max_h
end

function swarmwrap_measure_visible_height(box_reg)
  -- Measure the visible content height of a box register.
  -- Returns: max rule height (the colored rectangle's visible extent).
  -- No bonus, no minimum — the raw rule height gives the tightest
  -- possible parshape, producing per-session ratios of ~1.0-1.2x.
  -- The parshape loop (in .sty) naturally rounds up to the next
  -- baselineskip, providing ~1 line of clearance below the figure.
  -- If no rules found, falls back to ht+dp minus strut.
  local box = tex.box[box_reg]
  if not box then
    texio.write_nl("swarmwrap DEBUG: box[" .. box_reg .. "] is nil")
    return 0
  end

  local max_rule = 0
  if box.head then
    max_rule = find_max_rule_height(box.head)
  end

  local bs = tex.skip["baselineskip"].width
  local bs_pt = bs / 65536.0

  if max_rule > 0 then
    -- Use raw rule height — no bonus, no minimum.
    -- The parshape loop adds 1 extra line of clearance automatically
    -- (since nl = ceil(max_rule / bs), the zone is always > max_rule).
    local result = max_rule
    texio.write_nl(string.format("swarmwrap DEBUG: box[%s] ht=%s dp=%s max_rule=%s bs=%.1f result=%s",
      box_reg,
      tostring(box.height / 65536.0),
      tostring(box.depth / 65536.0),
      tostring(max_rule / 65536.0),
      bs_pt,
      tostring(result / 65536.0)))
    return result
  else
    -- No rules found (unusual — maybe just text or an image).
    -- Fall back to box height minus strut.
    local strutbox = tex.box["strutbox"]
    local fallback = box.height + box.depth - strutbox.height - strutbox.depth
    if fallback < bs then
      fallback = bs
    end
    texio.write_nl(string.format("swarmwrap DEBUG: NO RULES box[%s] fallback=%s",
      box_reg, tostring(fallback / 65536.0)))
    return fallback
  end
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

texio.write_nl("swarmwrap: callback v3.42 loaded (penalty + visible height)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: penalty")
texio.write_nl("swarmwrap: callback registered successfully")

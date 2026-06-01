-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.84
--
-- LAYER 1 (v3.55): Pre-check needspace. Before TeX breaks a paragraph,
-- check if the current parshape's narrow zone fits on the remaining
-- page space. If not, reduce narrow entries or clear parshape entirely.
-- (Fires only once per unique paragraph shape due to LuaTeX caching.)
--
-- LAYER 2 (v3.78): Active page-break guard in post_linebreak_filter.
-- After TeX breaks lines, counts leading narrow hlists and compares their
-- total height against remaining page space. If the narrow zone would
-- overflow the page (with 2bs safety margin), inserts a -10000 penalty
-- before the first narrow line, forcing TeX to break the page BEFORE
-- entering the narrow zone.
--
-- v3.75: Removed fig_pages table and swarmwrap_mark_fig_placed() — these
-- were write-only dead state (fig_pages was populated but never read by
-- any active code). Also removed swarmwrap@remaining dimen reference.
--
-- v3.77: Removed disabled Layer 2 (swarmwrap_post_lb function + dead
-- is_narrow_hbox/has_text_content helpers). Layer 2 transition penalty
-- was investigated over v3.54-v3.72 and disabled in v3.73 because DEFER
-- 8bs eliminates ghost narrowing without penalties. The disabled function
-- was 53 lines of dead code in the hot Lua callback path. Full history
-- is documented in swarmwrap.sty header (PRODUCTION CONFIGURATION NOTE).
--
-- v3.81: Removed dead Layer 3 (shipout_filter ghost-fix). The shipout_filter
-- callback registration FAILS with luaotfload conflict (documented since
-- v3.45, BLACKBOARD Task #199). ~110 lines of dead code removed:
-- swarmwrap_ghost_fix, fig_pages, swarmwrap_mark_fig_placed, has_figure_rule,
-- glyph_id, ghost_fix_count, and shipout_filter registration. Also removed
-- \directlua{swarmwrap_mark_fig_placed()} calls from swarmwrap.sty.
--
-- IMPORTANT: pre_linebreak_filter and post_linebreak_filter fire only
-- ONCE per document when \lipsum is used (LuaTeX optimization).

local hlist_id = node.id("hlist")
local vlist_id = node.id("vlist")
local rule_id = node.id("rule")
local glue_id = node.id("glue")
local kern_id = node.id("kern")
-- v3.77: Removed glyph_id, disc_id, penalty_id — were used only by
-- disabled Layer 2 (swarmwrap_post_lb) and its helpers (has_text_content).

function swarmwrap_measure_visible_height(box_reg)
  -- v3.84: RESTORED v3.58/v3.82 max-rule-traversal for narrow zone height.
  -- v3.83 incorrectly used box.height+box.depth (full box) for BOTH narrow
  -- zone AND overlap prevention, causing +36 pages, ghost/hollow return.
  -- The HYBRID approach separates the two concerns:
  --   fh_narrow (this function): max-rule + 1bs buffer (tight wrapping)
  --   fh@val (.sty): box.height+box.depth+1bs (full overlap prevention)
  local box = tex.box[box_reg]
  if not box then return 0 end
  local bs = tex.skip["baselineskip"].width
  local max_rule_h = 0

  -- Recursively search for rule nodes inside the box
  local function find_max_rule(head)
    if not head then return end
    for n in node.traverse(head) do
      if n.id == rule_id then
        -- Rule node: check its height + depth
        local rh = n.height + n.depth
        if rh > max_rule_h then max_rule_h = rh end
      elseif n.id == hlist_id then
        find_max_rule(n.head)
      elseif n.id == vlist_id then
        find_max_rule(n.head)
      end
    end
  end

  -- Search the box content
  if box.head then
    find_max_rule(box.head)
  end

  -- Fallback: if no rule found, use the full box height
  if max_rule_h <= 0 then
    max_rule_h = box.height + box.depth
  end

  -- Add buffer: 1 baselineskip below the rule to ensure text stays narrow
  -- while beside the figure's bottom edge.
  max_rule_h = max_rule_h + bs

  -- Minimum: 1 baselineskip
  if max_rule_h < bs then max_rule_h = bs end

  return max_rule_h
end

-- LAYER 1 (v3.55->v3.78): Pre-check needspace + parshape guard.
-- Before TeX breaks a paragraph, check if the current parshape's narrow zone
-- fits on the remaining page space. If not, reduce narrow entries or clear
-- parshape entirely.
-- v3.78 enhancement: Also check if the FULL paragraph (narrow + full-width)
-- would cause a page break within the narrow zone. If remaining space is less
-- than narrow_height + full_width_continuation_height, clear parshape entirely
-- to prevent ghost narrowing from parshape carry-over across page breaks.
function swarmwrap_needspace(head, groupcode)
  local nl = tex.count["swarmwrap@nl@lua"]
  if nl <= 0 then
    return head
  end

  local ps = tex.parshape
  if not ps then
    return head
  end

  local num_lines = 0
  for k, v in pairs(ps) do
    if type(v) == "table" then
      num_lines = num_lines + 1
    end
  end
  if num_lines < 2 then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  local bs = tex.skip["baselineskip"].width
  if bs <= 0 or linewidth <= 0 then
    return head
  end

  local narrow_count = 0
  for k, v in pairs(ps) do
    if type(v) == "table" then
      local w = v[2]
      if w > 0 and w < linewidth * 0.85 then
        narrow_count = narrow_count + 1
      else
        break
      end
    end
  end

  if narrow_count == 0 then
    return head
  end

  local remaining
  local ok, err = pcall(function()
    remaining = tex.dimen["pagegoal"] - tex.dimen["pagetotal"]
  end)
  if not ok then
    return head  -- Safety: skip needspace check if dimen access fails
  end

  local needed = (narrow_count + 4) * bs

  if remaining < needed then
    local safe_lines = math.max(0, math.floor((remaining - 2 * bs) / bs))

    texio.write_nl(string.format(
      "[NEEDSPACE] pg=%d narrow=%d needed=%.1f remaining=%.1f safe=%d REDUCED",
      tex.count["c@page"], narrow_count, needed/65536, remaining/65536, safe_lines))

    if safe_lines < 1 then
      texio.write_nl(string.format(
        "[NEEDSPACE] pg=%d CLEARING parshape — insufficient space for any narrow lines",
        tex.count["c@page"]))
      tex.parshape = nil
    elseif safe_lines < narrow_count then
      local new_ps = {}
      for k, v in pairs(ps) do
        if type(v) == "table" and k <= safe_lines then
          new_ps[k] = {v[1], v[2]}
        end
      end
      new_ps[safe_lines + 1] = {0, linewidth}
      tex.parshape = new_ps
    end
  else
    -- v3.78: Check if the paragraph would cause a page break within the
    -- narrow zone even though the narrow zone itself fits.
    -- If remaining space is tight (narrow zone fills > 60% of page),
    -- the full-width continuation after the narrow zone may force TeX to
    -- break the page within the narrow zone when it tries to fit both.
    -- In that case, clear parshape to prevent ghost carry-over.
    local fill_ratio = needed / (remaining + 0.001)
    if fill_ratio > 0.60 then
      -- Remaining space is tight. The paragraph is likely long enough
      -- that TeX will break the page within the narrow zone.
      -- Clear parshape to make entire paragraph full-width.
      -- The \par patch will re-apply parshape for subsequent paragraphs.
      texio.write_nl(string.format(
        "[NEEDSPACE] pg=%d narrow=%d fill=%.0f%% — CLEARING parshape to prevent ghost narrowing",
        tex.count["c@page"], narrow_count, fill_ratio * 100))
      tex.parshape = nil
    end
  end

  return head
end

-- LAYER 2 (v3.78→v3.91): Active page-break guard in post_linebreak_filter.
-- After TeX breaks lines, count the resulting narrow hlists (width < 85% of
-- linewidth). If narrow lines exist AND remaining page space is less than
-- the narrow zone height + a safety margin, insert a strong penalty before
-- the first narrow line to force a page break BEFORE the narrow zone.
-- This prevents parshape carry-over (ghost narrowing) across page breaks.
-- The penalty is inserted into the broken node list; TeX's page breaker
-- will see it and break the page there instead of within the narrow zone.
--
-- v3.91 enhancement: Also check TOTAL paragraph height. If the full
-- paragraph (narrow + full-width) exceeds remaining space AND there are
-- narrow lines, insert a penalty at the narrow→full transition point.
-- This forces TeX to break at the transition rather than within the narrow
-- zone, preventing near-empty carry-over pages (1-2 narrow lines, no figure).
-- Without this, a long paragraph that overflows the page mid-narrow-zone
-- creates a carry-over page with just 1-2 narrow lines — classified as
-- NEAR-EMPTY by the detection script. The penalty at the transition
-- ensures the carry-over is full-width text (no narrow, no ghost).
function swarmwrap_pagebreak_guard(head, groupcode)
  local tw = tex.dimen["swarmwrap@tw@lua"]
  if tw <= 0 then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  if linewidth <= 0 then
    return head
  end

  -- The broken head is a vlist of hlists. Count leading narrow hlists
  -- and compute total paragraph height.
  local narrow_count = 0
  local total_lines = 0
  local total_height = 0
  local narrow_end_prev = nil  -- node before last narrow hlist (for transition penalty)

  for n in node.traverse(head) do
    if n.id == hlist_id then
      total_lines = total_lines + 1
      total_height = total_height + n.height + n.depth
      -- Compare hlist width against the text width (tw).
      -- Narrow lines have width approximately = tw.
      -- Full-width lines have width approximately = linewidth.
      -- Use tw + 14pt as the narrow threshold (14pt gap between text and figure).
      if n.width > 0 and n.width < (linewidth * 0.85) then
        narrow_count = narrow_count + 1
        narrow_end_prev = n  -- track last narrow line for transition penalty
      else
        break  -- Stop counting at first full-width line
      end
    elseif n.id == node.id("penalty") then
      -- Skip penalty nodes (inter-line penalties)
    elseif n.id == node.id("glue") then
      -- Skip inter-line glue
    elseif n.id == node.id("kern") then
      -- Skip kern nodes
    end
  end

  if narrow_count == 0 then
    return head
  end

  -- Check remaining page space
  local remaining
  local ok, err = pcall(function()
    remaining = tex.dimen["pagegoal"] - tex.dimen["pagetotal"]
  end)
  if not ok then
    return head
  end

  local bs = tex.skip["baselineskip"].width
  if bs <= 0 then
    return head
  end

  -- The narrow zone height = narrow_count * baselineskip
  -- If this exceeds remaining space (with 2bs safety margin),
  -- the page breaker will likely break within the narrow zone.
  -- Insert a penalty before the first narrow line to force break BEFORE.
  local narrow_height = narrow_count * bs
  local threshold = remaining - 2 * bs

  if narrow_height > threshold and threshold > 0 then
    -- Find the first narrow hlist and insert penalty before it
    local prev = nil
    for n in node.traverse(head) do
      if n.id == hlist_id and n.width > 0 and n.width < (linewidth * 0.85) then
        -- Insert penalty -10000 before this hlist
        local pen = node.new(node.id("penalty"))
        pen.penalty = -10000
        if prev then
          node.insert_after(head, prev, pen)
        else
          -- Insert at head
          pen.next = head
          head = pen
        end
        texio.write_nl(string.format(
          "[PAGEBREAK-GUARD] pg=%d narrow=%d height=%.1fpt remaining=%.1fpt -> PENALTY INSERTED",
          tex.count["c@page"], narrow_count, narrow_height/65536, remaining/65536))
        return head
      end
      prev = n
    end
  end

  -- v3.91: Near-empty carry-over prevention (Task #275).
  -- Check if the TOTAL paragraph height exceeds remaining page space.
  -- If so, TeX will break the paragraph somewhere on the page.
  -- If the break happens within the narrow zone, the carry-over is
  -- 1-2 narrow lines on a page with no figure — a NEAR-EMPTY page.
  -- Fix: insert a penalty at the narrow→full transition point.
  -- This encourages TeX to break AFTER the narrow zone (in the full-width
  -- portion), so the carry-over is full-width text, not narrow.
  -- The carry-over page starts with full-width text and no ghost.
  if total_height > remaining and remaining > 0 and narrow_end_prev then
    -- Find the narrow→full transition: the point after the last narrow
    -- hlist before the first full-width hlist.
    -- Insert penalty AFTER the last narrow line.
    local inserted = false
    for n in node.traverse(head) do
      if n.id == hlist_id and n.width > 0 and n.width < (linewidth * 0.85) then
        narrow_end_prev = n
      elseif n.id == hlist_id and n.width >= (linewidth * 0.85) then
        -- This is the first full-width line. Insert penalty before it.
        local pen = node.new(node.id("penalty"))
        pen.penalty = -10000
        node.insert_after(head, narrow_end_prev, pen)
        texio.write_nl(string.format(
          "[NEAR-EMPTY-GUARD] pg=%d narrow=%d total=%.1fpt remaining=%.1fpt -> TRANSITION PENALTY",
          tex.count["c@page"], narrow_count, total_height/65536, remaining/65536))
        head = head  -- unchanged, but modified in-place
        return head
      end
    end
  end

  return head
end

function swarmwrap_measure_caption_zone(box_reg)
  -- v3.89: Measure the vertical extent of content BELOW the tallest rule.
  -- Used for precise caption zone height instead of the crude
  -- fh@val - fh_narrow estimate (v3.86, Task #267).
  --
  -- Simple and robust approach: box total height minus max rule height
  -- gives the caption zone. The box contains the minipage which holds
  -- the figure + caption. fh_narrow already includes 1bs buffer below
  -- the rule, so we subtract fh_narrow from the box total.
  --
  -- box.h+d = total minipage content (rule + caption + padding/struts)
  -- fh_narrow = max_rule_h + 1bs (already computed by measure_visible_height)
  -- caption_zone ≈ box.h+d - fh_narrow - 1bs (subtract extra bs from box top strut)
  --
  -- For bare images (no caption), box.h+d ≈ fh_narrow + small padding,
  -- so caption_zone ≈ 0 (or small). The \ifdim guard in the .sty handles this.
  local box = tex.box[box_reg]
  if not box then return 0 end

  local max_rule_h = 0
  local function find_max_rule_h(head)
    if not head then return end
    for n in node.traverse(head) do
      if n.id == rule_id then
        local rh = n.height + n.depth
        if rh > max_rule_h then max_rule_h = rh end
      elseif n.id == hlist_id or n.id == vlist_id then
        if n.head then find_max_rule_h(n.head) end
      end
    end
  end
  if box.head then find_max_rule_h(box.head) end
  if max_rule_h <= 0 then return 0 end

  -- The box total height minus the rule height gives the "extra" content
  -- below the rule (caption + inter-line glue + minipage padding).
  -- NOTE: Do NOT subtract bs here. The .sty loop divides by bs and uses
  -- ceiling (loop while >0), so (box - rule) / bs matches v3.86's
  -- (fh@val - fh_narrow) / bs exactly. Subtracting bs would undercount
  -- by 1 line, causing caption-text overlap regression (v3.89 bug).
  local bs = tex.skip["baselineskip"].width
  local caption_h = (box.height + box.depth) - max_rule_h
  if caption_h < 0 then caption_h = 0 end

  texio.write_nl(string.format("[CAPTION-ZONE] max_rule=%.1fpt caption_zone=%.1fpt box=%.1fpt",
    max_rule_h/65536, caption_h/65536, (box.height+box.depth)/65536))

  return caption_h
end

texio.write_nl("swarmwrap: callback v3.91 loaded (needspace + pagebreak-guard + caption-zone measurement)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_pagebreak_guard, "swarmwrap: pagebreak guard")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

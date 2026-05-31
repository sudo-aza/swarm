-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.78
--
-- LAYER 1 (v3.55): Pre-check needspace. Before TeX breaks a paragraph,
-- check if the current parshape's narrow zone fits on the remaining
-- page space. If not, reduce narrow entries or clear parshape entirely.
-- (Fires only once per unique paragraph shape due to LuaTeX caching.)
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
-- IMPORTANT: pre_linebreak_filter and post_linebreak_filter fire only
-- ONCE per document when \lipsum is used (LuaTeX optimization).

local hlist_id = node.id("hlist")
local vlist_id = node.id("vlist")
local rule_id = node.id("rule")
-- v3.77: Removed glyph_id, disc_id, penalty_id — were used only by
-- disabled Layer 2 (swarmwrap_post_lb) and its helpers (has_text_content).

function swarmwrap_measure_visible_height(box_reg)
  -- v3.58: Traverse savebox nodes to find the tallest \rule node
  -- (the colored rectangle that IS the figure). This gives a much tighter
  -- narrow zone than using box.height+box.depth (which includes caption
  -- text, abovecaptionskip, and parskip overhead).
  -- The full savebox height is still used for overlap prevention (fh@val).
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
  -- while beside the figure's bottom edge. Without this, full-width text
  -- can overlap the figure's lower portion.
  max_rule_h = max_rule_h + bs

  -- Minimum: 1 baselineskip
  if max_rule_h < bs then max_rule_h = bs end

  return max_rule_h
end

-- LAYER 1 (v3.55→v3.78): Pre-check needspace + parshape guard.
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

-- LAYER 2 (v3.78): Active page-break guard in post_linebreak_filter.
-- After TeX breaks lines, count the resulting narrow hlists (width < 85% of
-- linewidth). If narrow lines exist AND remaining page space is less than
-- the narrow zone height + a safety margin, insert a strong penalty before
-- the first narrow line to force a page break BEFORE the narrow zone.
-- This prevents parshape carry-over (ghost narrowing) across page breaks.
-- The penalty is inserted into the broken node list; TeX's page breaker
-- will see it and break the page there instead of within the narrow zone.
function swarmwrap_pagebreak_guard(head, groupcode)
  local tw = tex.dimen["swarmwrap@tw@lua"]
  if tw <= 0 then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  if linewidth <= 0 then
    return head
  end

  -- The broken head is a vlist of hlists. Count leading narrow hlists.
  local narrow_count = 0
  local total_lines = 0
  for n in node.traverse(head) do
    if n.id == hlist_id then
      total_lines = total_lines + 1
      -- Compare hlist width against the text width (tw).
      -- Narrow lines have width approximately = tw.
      -- Full-width lines have width approximately = linewidth.
      -- Use tw + 14pt as the narrow threshold (14pt gap between text and figure).
      if n.width > 0 and n.width < (linewidth * 0.85) then
        narrow_count = narrow_count + 1
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

  return head
end

-- LAYER 3 (v3.80): shipout_filter — ghost-narrowing fix at shipout time.
-- This fires for EVERY page shipped to PDF (not subject to LuaTeX
-- paragraph caching). It detects narrow hlists that have no adjacent
-- figure and widens them to full page width using node.hpack.
--
-- HOW IT WORKS:
-- 1. Track which pages have figures placed on them via a Lua table.
--    swarmwrap_mark_fig_placed() is called from \swarmwrapnext in the .sty.
-- 2. At shipout time, for each page:
--    a. If the page has no recorded figure, ALL narrow hlists are ghost → widen
--    b. If the page HAS a recorded figure, find figure's vertical extent,
--       then widen only narrow hlists ABOVE or BELOW the figure zone
--    c. Narrow hlists BESIDE the figure are left alone (correct wrapping)
--
-- WIDENING: Uses node.hpack('exactly', linewidth) to re-pack the hbox
-- content at full page width. This redistributes text across the full line.
-- v3.28 tried this and caused 71 overlaps because it widened lines BESIDE
-- the figure. v3.80 only widens lines NOT beside the figure.

local glyph_id = node.id("glyph")

-- Table tracking which pages have active figures
local fig_pages = {}  -- fig_pages[page_num] = {y_top, y_bottom}

-- Called from \swarmwrapnext after figure placement
function swarmwrap_mark_fig_placed()
  local pg = tex.count["c@page"]
  -- Just record that this page has a figure. The shipout_filter
  -- uses has_figure_rule() to detect figure presence per-hlist.
  fig_pages[pg] = true
end

-- Check if an hlist contains a figure rule (the colored rectangle)
-- This detects the \smash{\rlap{...}} figure content
local function has_figure_rule(hlist_node)
  if not hlist_node.head then return false end
  for n in node.traverse(hlist_node.head) do
    if n.id == hlist_id then
      -- Recurse into nested hlists (the \smash{\rlap} creates nested boxes)
      if has_figure_rule(n) then return true end
    elseif n.id == rule_id then
      -- Check if this is a large rule (figure, not a strut or rule)
      -- Figures have height > 20pt (at minimum 1.5cm = ~42pt)
      local rh = n.height + n.depth
      if rh > 655360 then  -- > 10pt in scaled units
        return true
      end
    end
  end
  return false
end

local ghost_fix_count = 0

function swarmwrap_ghost_fix(head, groupcode)
  local pg = tex.count["c@page"]
  
  -- Only process pages that have NO recorded figure.
  -- For pages WITH figures, DEFER 8bs prevents ghost narrowing.
  -- This avoids expensive per-hlist figure-rule scanning on every page,
  -- which blows TeX's conditional stack on large documents.
  if fig_pages[pg] then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  if linewidth <= 0 then
    return head
  end

  local narrow_threshold = linewidth * 0.85

  -- Fast single-pass: only widen narrow hlists (no figure check needed
  -- since we already confirmed no figure on this page)
  local function process_vlist(vlist_head)
    for n in node.traverse(vlist_head) do
      if n.id == vlist_id then
        if n.head then process_vlist(n.head) end
      elseif n.id == hlist_id then
        local hw = n.width
        if hw > 0 and hw < narrow_threshold then
          local new_h = node.hpack(n.head, linewidth, 'exactly')
          n.head = new_h.head
          n.width = linewidth
          ghost_fix_count = ghost_fix_count + 1
          if ghost_fix_count <= 30 then
            texio.write_nl(string.format(
              "[GHOST-FIX] pg=%d w=%d->%d (no fig page)",
              pg, hw/65536, linewidth/65536))
          end
        end
      end
    end
  end

  process_vlist(head)

  -- Clean up old entries
  for k, _ in pairs(fig_pages) do
    if k < pg - 2 then
      fig_pages[k] = nil
    end
  end

  return head
end

texio.write_nl("swarmwrap: callback v3.80 loaded (needspace + pagebreak-guard + ghost-fix shipout + rule-height measurement)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_pagebreak_guard, "swarmwrap: pagebreak guard")
luatexbase.add_to_callback("shipout_filter",
  swarmwrap_ghost_fix, "swarmwrap: ghost narrowing fix")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")
texio.write_nl("swarmwrap: shipout_filter registered successfully")

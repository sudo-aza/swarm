-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.72
--
-- LAYER 1 (v3.55): Pre-check needspace. Before TeX breaks a paragraph,
-- check if the current parshape's narrow zone fits on the remaining
-- page space. If not, reduce narrow entries or clear parshape entirely.
-- (Fires only once per unique paragraph shape due to LuaTeX caching.)
--
-- LAYER 2 (v3.70): Conditional transition penalty. After TeX breaks a
-- paragraph, find the LAST narrow line (narrow->full transition point)
-- and insert a penalty there. v3.70 key change: penalty strength is
-- CONDITIONAL on remaining page space:
--   - If narrow_count * baselineskip > (pagegoal - pagetotal):
--     Use -10000 (FORCED break). TeX MUST break the page at the
--     transition, preventing narrow lines from carrying over to the
--     next page where no figure exists (ghost narrowing).
--   - Otherwise: use -5000 (normal encouragement).
-- This is the FIRST time -10000 has been tried at the transition.
-- Previous: -2000 (v3.54) and -5000 (v3.69) are discretionary and
-- TeX can override them when the page is overfull — exactly when
-- ghost narrowing occurs. -10000 is mandatory.
-- (Fires only once per unique paragraph shape due to LuaTeX caching.)
--
-- IMPORTANT: pre_linebreak_filter and post_linebreak_filter fire only
-- ONCE per document when \lipsum is used (LuaTeX optimization).

local glyph_id = node.id("glyph")
local disc_id = node.id("disc")
local penalty_id = node.id("penalty")
local hlist_id = node.id("hlist")
local vlist_id = node.id("vlist")
local rule_id = node.id("rule")

local fig_pages = {}

function swarmwrap_mark_fig_placed()
  local pg = tex.count["c@page"]
  fig_pages[pg] = true
end

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

-- Check if an hbox contains actual text glyphs.
local function has_text_content(head)
  for n in node.traverse(head) do
    if n.id == glyph_id then return true end
    if n.id == disc_id then return true end
    if n.id == hlist_id then
      if has_text_content(n.head) then return true end
    end
  end
  return false
end

-- Check if an hbox is narrow (part of wrapping zone).
-- v3.69: Use midpoint threshold between tw and linewidth.
-- Previous: hbox.width < 0.8*linewidth — this missed narrow lines
-- at ~300pt (for typical tw=302pt, linewidth=359pt, threshold=287pt).
-- A narrow line has width ≈ tw (the wrapping text width). A full-width
-- line has width ≈ linewidth. Using the midpoint gives a robust boundary:
--   threshold = (tw + linewidth) / 2
-- For typical values: (302 + 359) / 2 = 330.5pt — catches all narrow
-- lines up to ~330pt (including emergency-stretched lines).
local function is_narrow_hbox(hbox, tw, lw)
  if tw <= 0 then return false end
  if lw <= 0 then return false end
  local threshold = (tw + lw) / 2
  return hbox.width < threshold
end

-- LAYER 1: Pre-check needspace (Approach B from Researcher's research).
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
  end

  return head
end

-- LAYER 2: Conditional transition penalty in post_linebreak_filter (Task #214).
-- After TeX breaks the paragraph into lines (hlists), find the narrow->full
-- transition point and insert a penalty. v3.70 key change:
-- CONDITIONAL penalty based on remaining page space. Count narrow lines (K)
-- in the broken result and compare K * baselineskip against remaining page
-- space (pagegoal - pagetotal).
--
-- If narrow zone exceeds remaining space:
--   - Use -10000 (FORCED break). TeX MUST break the page at the
--     narrow->full transition. This prevents narrow lines from carrying
--     over to the next page where no figure exists (ghost narrowing).
--   - This has NEVER been tried before. Previous attempts used discretionary
--     penalties: -2000 (v3.54), -5000 (v3.69). TeX can override discretionary
--     penalties when the page is overfull, which is exactly when ghost
--     narrowing occurs. -10000 is mandatory — TeX cannot override it.
--
-- If narrow zone fits on the remaining page:
--   - Use -5000 (normal encouragement, no forced break needed).
--
-- Trade-off: forced breaks may increase page count slightly when paragraphs
-- start near page bottoms. But this only fires for paragraphs where the narrow
-- zone doesn't fit — exactly the ghost-narrowing risk cases.
function swarmwrap_post_lb(head, groupcode)
  local nl = tex.count["swarmwrap@nl@lua"]

  if nl <= 0 then
    return head
  end

  local tw = tex.dimen["swarmwrap@tw@lua"]
  if tw <= 0 then
    return head
  end

  local lw = tex.dimen["linewidth"]
  if lw <= 0 then
    return head
  end

  -- Walk the broken paragraph to find the narrow->full transition
  -- AND count narrow lines for page-space estimation.
  local last_narrow = nil
  local narrow_count = 0
  local prev_was_narrow = false

  for n in node.traverse(head) do
    if n.id == hlist_id and has_text_content(n) then
      if is_narrow_hbox(n, tw, lw) then
        last_narrow = n
        narrow_count = narrow_count + 1
        prev_was_narrow = true
      else
        if prev_was_narrow then
          break  -- past the narrow->full transition
        end
      end
    end
  end

  -- No narrow lines found — nothing to do
  if not last_narrow then
    return head
  end

  -- v3.70: Conditional penalty based on remaining page space.
  -- pagegoal and pagetotal are TeX internals not accessible from Lua.
  -- Instead, read \swarmwrap@remaining (computed at \swarmwrapnext time).
  local penalty_value = -5000  -- default: normal encouragement
  local bs = tex.skip["baselineskip"].width
  if bs > 0 then
    local ok, err = pcall(function()
      local remaining = tex.dimen["swarmwrap@remaining"]
      if remaining <= 0 then return end
      local narrow_height = narrow_count * bs
      -- v3.72: DISABLED forced breaks (Task #232). QA insight: DEFER 8bs
      -- alone eliminates ghost narrowing via page-eject deferral (v3.67
      -- proved: 0 ghost, 1069 pages). Forced breaks (-10000) are too costly:
      -- 1206+ pages. Disabling forced breaks and relying on DEFER 8bs for
      -- ghost prevention gives much lower page count. The -5000 default
      -- penalty remains as light encouragement but won't force page breaks.
      -- Force-break code intentionally commented out for future tuning.
      --[[ ENABLE FOR FORCED BREAKS:
      if narrow_height > remaining then
        penalty_value = -10000
        texio.write_nl(string.format(
          "[FORCE-BREAK] pg=%d narrow=%d narrow_h=%.1fpt remaining=%.1fpt",
          tex.count["c@page"], narrow_count, narrow_height/65536, remaining/65536))
      end
      --]]
    end)
  end

  -- Insert penalty at the narrow->full transition.
  local pen = node.new(penalty_id)
  pen.penalty = penalty_value
  head, last_narrow = node.insert_after(head, last_narrow, pen)

  return head
end

texio.write_nl("swarmwrap: callback v3.72 loaded (needspace + conditional forced transition penalty + rule-height measurement)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: conditional forced transition penalty")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

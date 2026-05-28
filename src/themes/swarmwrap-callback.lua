-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.59: No code changes from v3.58. Detection script fixes only.
--   detect_excessive_narrowing: added vertical overlap filter (v10),
--   eliminated 99.7% false positives from short paragraph last-lines.
--   detect_figure_misaligned: added multicol column detection (v6.2),
--   eliminated 4 false positives from figures in left multicol columns.
--
-- LAYER 1 (v3.55): Pre-check needspace. Before TeX breaks a paragraph,
-- check if the current parshape's narrow zone fits on the remaining
-- page space. If not, reduce narrow entries or clear parshape entirely.
--
-- LAYER 2 (v3.54): Transition penalty. After TeX breaks a paragraph,
-- find the LAST narrow line (narrow->full transition point) and insert
-- a negative penalty (-2000) after it. This encourages TeX to break
-- the page at the transition rather than within the narrow zone.
--
-- IMPORTANT: Lua callbacks (pre_linebreak_filter, post_linebreak_filter)
-- fire only ONCE per document when \lipsum is used (LuaTeX optimization).
-- This means the callbacks cannot provide per-paragraph ghost-narrowing
-- prevention for \lipsum-based stress tests. All prevention must be
-- done at the TeX level (.sty's \par patch, list hook, item hook).
-- The callbacks are kept as a safety net for non-\lipsum documents.

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
-- Narrow = width significantly less than linewidth.
local function is_narrow_hbox(hbox, tw)
  if tw <= 0 then return false end
  local lw = tex.dimen["linewidth"]
  return hbox.width < lw * 0.8
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

  local remaining = tex.dimen["pagegoal"] - tex.dimen["pagetotal"]
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

function swarmwrap_post_lb(head, groupcode)
  local nl = tex.count["swarmwrap@nl@lua"]

  if nl <= 0 then
    return head
  end

  local tw = tex.dimen["swarmwrap@tw@lua"]
  if tw <= 0 then
    return head
  end

  -- Find the last narrow line (narrow->full transition point).
  local last_narrow = nil
  local prev_was_narrow = false

  for n in node.traverse(head) do
    if n.id == hlist_id and has_text_content(n) then
      local narrow = is_narrow_hbox(n, tw)
      if narrow then
        last_narrow = n
        prev_was_narrow = true
      else
        if prev_was_narrow then
          break
        end
      end
    end
  end

  -- Insert a negative penalty after the last narrow line.
  if last_narrow then
    local pen = node.new(penalty_id)
    pen.penalty = -2000
    head, last_narrow = node.insert_after(head, last_narrow, pen)
  end

  return head
end

texio.write_nl("swarmwrap: callback v3.58 loaded (needspace + transition penalty + rule-height measurement)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

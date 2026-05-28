-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.55: Pre-check needspace in pre_linebreak_filter + transition penalty.
--
-- LAYER 1 (new): Pre-check needspace. Before TeX breaks a paragraph,
-- check if the current parshape's narrow zone fits on the remaining
-- page space. If not, reduce narrow entries or clear parshape entirely.
-- This is a fundamentally different approach from penalties -- it prevents
-- ghost narrowing by ensuring the narrow zone never crosses a page
-- boundary. Based on Researcher's Approach B (needspace) and the
-- chickenize package's parshape modification technique.
--
-- LAYER 2 (v3.54): Transition penalty. After TeX breaks a paragraph,
-- find the LAST narrow line (narrow->full transition point) and insert
-- a negative penalty (-2000) after it. This encourages TeX to break
-- the page at the transition rather than within the narrow zone.

local glyph_id = node.id("glyph")
local disc_id = node.id("disc")
local penalty_id = node.id("penalty")
local hlist_id = node.id("hlist")

local fig_pages = {}

function swarmwrap_mark_fig_placed()
  local pg = tex.count["c@page"]
  fig_pages[pg] = true
end

function swarmwrap_measure_visible_height(box_reg)
  local box = tex.box[box_reg]
  if not box then return 0 end
  local bs = tex.skip["baselineskip"].width
  local raw_height = box.height + box.depth
  local visible = raw_height
  if visible < bs then visible = bs end
  return visible
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
  -- A line is narrow if its width is less than linewidth minus
  -- a generous threshold. We use 80% of linewidth as the cutoff.
  return hbox.width < lw * 0.8
end

-- LAYER 1: Pre-check needspace (Approach B from Researcher's research).
-- Fires BEFORE TeX breaks lines. Checks if the narrow zone fits on the
-- remaining page space. If not, reduces or clears parshape.
--
-- WHY THIS WORKS: The .sty's \par patch, list hook, and item hook set
-- parshape at paragraph/item boundaries. But at that point, \pagetotal
-- may not reflect all inter-paragraph spacing (\parskip, list overhead).
-- By the time pre_linebreak_filter fires, all spacing has been consumed
-- and \pagetotal is accurate. This second check catches cases where
-- the .sty's safety margin was insufficient.
--
-- tex.parshape format in LuaTeX: table of {indent, width} pairs, 1-indexed.
-- tex.parshape = nil when no parshape is active.
function swarmwrap_needspace(head, groupcode)
  -- Only process when wrapping is active
  local nl = tex.count["swarmwrap@nl@lua"]
  if nl <= 0 then
    return head
  end

  local ps = tex.parshape
  if not ps then
    return head
  end

  -- Count parshape entries
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

  -- Count narrow entries (they're always first, followed by trailing full-width)
  local narrow_count = 0
  for k, v in pairs(ps) do
    if type(v) == "table" then
      local w = v[2]  -- width
      if w > 0 and w < linewidth * 0.85 then
        narrow_count = narrow_count + 1
      else
        break  -- narrow entries are always first
      end
    end
  end

  if narrow_count == 0 then
    return head
  end

  -- Compute remaining page space
  local remaining = tex.dimen["pagegoal"] - tex.dimen["pagetotal"]

  -- Check: narrow zone + trailing entry + extra buffer must fit.
  -- Use generous 4bs buffer to catch edge cases where the paragraph
  -- is long enough to span a page break within the narrow zone.
  local needed = (narrow_count + 4) * bs

  if remaining < needed then
    -- Not enough room. Reduce narrow entries to what fits with 2bs clearance.
    local safe_lines = math.max(0, math.floor((remaining - 2 * bs) / bs))

    texio.write_nl(string.format(
      "[NEEDSPACE] pg=%d narrow=%d needed=%.1f remaining=%.1f safe=%d REDUCED",
      tex.count["c@page"], narrow_count, needed/65536, remaining/65536, safe_lines))

    if safe_lines < 1 then
      -- No room for any narrow lines -- clear parshape.
      tex.parshape = nil
    elseif safe_lines < narrow_count then
      -- Reduce narrow entries to what fits with clearance.
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

  -- Only process when wrapping is active
  if nl <= 0 then
    return head
  end

  local tw = tex.dimen["swarmwrap@tw@lua"]
  if tw <= 0 then
    return head
  end

  -- Find the last narrow line (narrow->full transition point).
  -- This is the ideal page-break point to prevent ghost narrowing.
  local last_narrow = nil
  local prev_was_narrow = false

  for n in node.traverse(head) do
    if n.id == hlist_id and has_text_content(n) then
      local narrow = is_narrow_hbox(n, tw)
      if narrow then
        last_narrow = n
        prev_was_narrow = true
      else
        -- We've hit a full-width line after narrow lines.
        -- The transition has been found.
        if prev_was_narrow then
          break
        end
      end
    end
  end

  -- Insert a negative penalty after the last narrow line.
  -- This encourages TeX to break the page here.
  -- v3.54: Use -2000 (strong encouragement).
  if last_narrow then
    local pen = node.new(penalty_id)
    pen.penalty = -2000
    head, last_narrow = node.insert_after(head, last_narrow, pen)
  end

  return head
end

texio.write_nl("swarmwrap: callback v3.55 loaded (needspace + transition penalty)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

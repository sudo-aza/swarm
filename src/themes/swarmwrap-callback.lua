-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.54: Penalty at parshape boundary to prevent ghost narrowing.
--
-- STRATEGY: After TeX breaks a paragraph into lines, find the LAST
-- narrow line (the narrow→full parshape transition point) and insert
-- a negative penalty (-2000) after it. This encourages TeX to break
-- the page at this point rather than in the middle of the narrow zone.
-- If the paragraph must span a page break, TeX will prefer to break at
-- the transition — continuation starts with full-width lines.
--
-- CRITICAL: Only insert at the transition point. Do NOT penalize
-- narrow lines (that caused page count regression in earlier attempt).
-- The negative penalty is a SUGGESTION, not a requirement.

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
  
  -- Find the last narrow line (narrow→full transition point).
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

texio.write_nl("swarmwrap: callback v3.54 loaded (transition penalty)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

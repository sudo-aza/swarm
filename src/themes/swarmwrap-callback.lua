-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.77
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

texio.write_nl("swarmwrap: callback v3.77 loaded (needspace + rule-height measurement)")
luatexbase.add_to_callback("pre_linebreak_filter",
  swarmwrap_needspace, "swarmwrap: needspace pre-check")
texio.write_nl("swarmwrap: pre_linebreak_filter registered successfully")

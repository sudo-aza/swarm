-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.51: Fix remaining ghost narrowing at 1000-fig scale (Task #199).
--   v3.50's Phase 2 glue_set widening REMOVED — it changed hbox.width and
--   glue_set but did NOT reposition text glyphs (same class of bug as v3.45).
--   Instead, rely on:
--   (1) Prohibitive penalty (10001, truly prohibitive in TeX) after ALL
--       narrow lines. Widened detection tolerance from 3.0pt to 10.0pt
--       to catch lines with emergencystretch.
--   (2) Page-space limit with 1-baselineskip safety margin (in .sty).

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

local function has_text_content(hbox)
  if not hbox.head then return false end
  local n = hbox.head
  while n do
    if n.id == 37 or n.id == 38 then return true end
    n = n.next
  end
  return false
end

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0
  if tw_sp <= 0 then return head end
  local linewidth = tex.dimen["linewidth"]
  local lw_val = linewidth / 65536.0
  local penalty_val = tex.count["swarmwrap@penalty"]

  -- Collect all line info
  local narrow_lines = {}
  local total_lines = 0
  local cur = head
  while cur do
    if cur.id == 0 then
      total_lines = total_lines + 1
      local w = cur.width / 65536.0
      -- v3.51: Widened tolerance from 3.0pt to 10.0pt. Some narrow lines
      -- with emergencystretch had width > tw+3.0 and missed the penalty.
      -- Also check that width < linewidth (not a full-width line).
      if w <= tw_val + 10.0 and w > 0 and w < lw_val * 0.95 and has_text_content(cur) then
        narrow_lines[#narrow_lines + 1] = {
          node = cur,
          line_index = total_lines,
          width = w
        }
      end
    end
    cur = cur.next
  end

  -- Insert prohibitive penalties after all narrow lines
  -- Penalty > 10000 is truly prohibitive in TeX — TeX will not break
  -- at this point unless the page is completely overfull with no
  -- alternative break point.
  if penalty_val > 0 and #narrow_lines > 0 then
    for i = 1, #narrow_lines do
      local p = node.new(node.id("penalty"))
      p.penalty = penalty_val
      node.insert_after(head, narrow_lines[i].node, p)
    end
    texio.write_nl(string.format(
      "swarmwrap post_lb: inserted %d penalties (val=%d) on page %d",
      #narrow_lines, penalty_val, tex.count["c@page"]))
  end

  return head
end

texio.write_nl("swarmwrap: callback v3.51 loaded (prohibitive penalty only)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.50: Fix carry-over narrowing — penalty + page-fit widening (Task #204).
--   Previous approaches FAILED:
--   - v3.45: glue-stretch in pre_shipout_filter (changes don't propagate)
--   - v3.46: node.hpack in pre_shipout_filter (pcall hides fatal error, no-op)
--   FIX (three-part):
--   (1) Penalty 10M after narrow lines (first line of defense).
--   (2) Page-space limit in \par patch extensions (in swarmwrap.sty).
--   (3) post_linebreak_filter widening: estimate which narrow lines will
--       carry over to next page (based on paragraph height vs available
--       page space) and widen them by adjusting glue_set. This fires
--       during line breaking, so changes DO propagate to PDF.

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
      if w <= tw_val + 3.0 and w > 0 and has_text_content(cur) then
        narrow_lines[#narrow_lines + 1] = {
          node = cur,
          line_index = total_lines,
          width = w
        }
      end
    end
    cur = cur.next
  end

  -- Phase 1: Insert penalties after narrow lines
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

  -- Phase 2: Widen narrow lines that will carry over
  if #narrow_lines == 0 or total_lines == 0 then return head end

  local pagegoal = tex.dimen["pagegoal"] / 65536.0
  local pagetotal = tex.dimen["pagetotal"] / 65536.0
  local baselineskip = tex.skip["baselineskip"].width / 65536.0
  if baselineskip < 1.0 then baselineskip = 13.6 end

  local available = pagegoal - pagetotal
  local para_height = total_lines * baselineskip

  if para_height <= available then
    return head
  end

  local lines_fit = math.floor(available / baselineskip)
  if lines_fit < 0 then lines_fit = 0 end
  if lines_fit >= total_lines then return head end

  local current_page = tex.count["c@page"]
  local next_page_has_fig = fig_pages[current_page + 1]
  if next_page_has_fig then
    return head
  end

  local widened = 0
  for i = 1, #narrow_lines do
    local entry = narrow_lines[i]
    if entry.line_index > lines_fit then
      local hbox = entry.node
      local current_w = hbox.width
      if current_w < linewidth * 0.95 then
        local stretch = linewidth - current_w
        if stretch > 0 then
          local ratio = stretch / math.max(current_w, 1)
          hbox.width = linewidth
          if hbox.glue_set > 0 then
            hbox.glue_set = hbox.glue_set * (1.0 + ratio)
          else
            hbox.glue_set = ratio
            hbox.glue_sign = 1
          end
          widened = widened + 1
        end
      end
    end
  end

  if widened > 0 then
    texio.write_nl(string.format(
      "swarmwrap post_lb: widened %d carry-over lines on page %d (fit=%d, total=%d)",
      widened, current_page, lines_fit, total_lines))
  end

  return head
end

texio.write_nl("swarmwrap: callback v3.50 loaded (penalty + page-fit widening)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty + widening")
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

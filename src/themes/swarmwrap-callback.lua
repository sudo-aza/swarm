-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.46: Fix shipout filter -- use node.hpack for proper line widening.
--   v3.45 glue-stretch approach set hbox.width and glue_set but did NOT
--   reposition text glyphs (same class of bug as v3.27/v3.29). QA verified.
--   FIX: node.hpack(head, target_width, exactly) actually redistributes
--   inter-word glue and repositions all glyphs to fill target width.
--   Also: per-page fig_pages table replaces single fig_page counter.

local debug_mode = false
local swarmwrap_shipout_count = 0
local fig_pages = {}

function swarmwrap_mark_fig_placed()
  local pg = tex.count["c@page"]
  fig_pages[pg] = true
end

local function widen_hbox(hbox, target_width_sp)
  if not hbox.head then return false end
  if hbox.width >= target_width_sp then return false end
  local has_content = false
  local n = hbox.head
  while n do
    if n.id == 37 or n.id == 38 then has_content = true; break end
    n = n.next
  end
  if not has_content then return false end
  local ok, new_box = pcall(function()
    return node.hpack(hbox.head, target_width_sp, 'exactly')
  end)
  if not ok or not new_box then return false end
  if new_box.glue_sign == 1 and new_box.glue_set > 10.0 then
    hbox.head = new_box.head; new_box.head = nil; node.free(new_box)
    return false
  end
  local new_head = new_box.head; new_box.head = nil
  hbox.width = new_box.width; hbox.height = new_box.height
  hbox.depth = new_box.depth; hbox.glue_set = new_box.glue_set
  hbox.glue_sign = new_box.glue_sign; hbox.glue_order = new_box.glue_order
  hbox.head = new_head; node.free(new_box)
  return true
end

function swarmwrap_shipout(head, groupcode)
  swarmwrap_shipout_count = swarmwrap_shipout_count + 1
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local current_page = tex.count["c@page"]
  local linewidth = tex.dimen["linewidth"]
  local tw_val = (tw_sp > 0) and (tw_sp / 65536.0) or 0
  local lw_val = linewidth / 65536.0
  local narrow_max = lw_val * 0.88
  local narrow_min = 100
  if tw_sp <= 0 then return head end
  if fig_pages[current_page] then return head end
  local fixed = 0; local total_narrow = 0; local total_wide = 0
  local wide_min = lw_val * 0.88
  local function count_hboxes(cur, depth)
    while cur do
      if cur.id == 0 then
        local hw = cur.width / 65536.0
        if hw > narrow_min then
          if hw < narrow_max then total_narrow = total_narrow + 1
          elseif hw >= wide_min then total_wide = total_wide + 1 end
        end
      elseif cur.id == 1 and depth < 5 then
        if cur.head then count_hboxes(cur.head, depth + 1) end
      end
      cur = cur.next
    end
  end
  if head.head then count_hboxes(head.head, 0) end
  local is_ghost = (total_wide == 0) or (total_narrow > total_wide * 3)
  if not is_ghost then return head end
  local function fix_hboxes(cur, depth)
    while cur do
      if cur.id == 0 then
        local hw = cur.width / 65536.0
        if hw > narrow_min and hw < narrow_max then
          if widen_hbox(cur, linewidth) then fixed = fixed + 1 end
        end
      elseif cur.id == 1 and depth < 5 then
        if cur.head then fix_hboxes(cur.head, depth + 1) end
      end
      cur = cur.next
    end
  end
  if head.head then fix_hboxes(head.head, 0) end
  return head
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

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0
  if tw_sp <= 0 then return head end
  local linewidth = tex.dimen["linewidth"] / 65536.0
  local penalty_val = tex.count["swarmwrap@penalty"]
  if penalty_val > 0 then
    local current = head
    while current do
      if current.id == 0 then
        local lw = current.width / 65536.0
        if lw <= tw_val + 3.0 and lw > 0 then
          local p = node.new(node.id("penalty"))
          p.penalty = penalty_val
          node.insert_after(head, current, p)
        end
      end
      current = current.next
    end
  end
  return head
end

texio.write_nl("swarmwrap: callback v3.46 loaded (carry-over penalty + node.hpack shipout fix)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
local shipout_ok = pcall(function()
  luatexbase.add_to_callback("shipout_filter",
    swarmwrap_shipout, "swarmwrap: ghost-narrowing fix")
end)
if shipout_ok then
  texio.write_nl("swarmwrap: shipout_filter registered successfully")
else
  local pre_ok = pcall(function()
    luatexbase.add_to_callback("pre_shipout_filter",
      swarmwrap_shipout, "swarmwrap: ghost-narrowing fix")
  end)
  if pre_ok then
    texio.write_nl("swarmwrap: pre_shipout_filter registered (fallback)")
  else
    texio.write_nl("swarmwrap: shipout_filter unavailable")
  end
end
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

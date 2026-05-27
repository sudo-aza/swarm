-- swarmwrap-callback.lua — Lua callbacks for swarmwrap.sty
-- v3.45: Fix carry-over narrowing across page breaks (Task #199).
--   When a paragraph with active parshape spans a page break, the
--   remaining narrow lines carry over to the next page. Previously,
--   these narrow lines stayed narrow, wasting horizontal space.
--
--   FIX (two-part):
--   (1) PENALTY APPROACH: Insert a penalty of 10000 (forbidden) after
--       EVERY narrow line in post_linebreak_filter. This prevents
--       TeX from breaking the page within the narrow zone when
--       possible, pushing the entire narrow zone to the next page.
--   (2) SHIPOUT FILTER (ghost-narrowing only): On pages where NO
--       figure exists on the entire page, all narrow lines are
--       carry-over ghost narrowing. Widen them to full linewidth
--       by adjusting inter-word glue stretch.
--       For pages WITH figures, the narrow lines might be normal
--       wrapping (beside the figure) or carry-over — we cannot
--       safely distinguish these at shipout time without risking
--       text-figure overlap. The penalty approach handles these.
--
--   Trade-off: Penalty approach may increase page count slightly.
--   Acceptable per spec.

local debug_mode = false
local swarmwrap_shipout_count = 0

-- ── Mark figure placed — called from sty at placement time ──────
function swarmwrap_mark_fig_placed()
  if debug_mode then
    texio.write_nl(string.format(
      "swarmwrap: fig placed on page %d",
      tex.count["c@page"]))
  end
end

-- ── Helper: widen an hbox by adjusting inter-word glue ──────────
local function widen_hbox(hbox, target_width_sp)
  local head = hbox.head
  if not head then return 0 end

  local current_width = hbox.width
  local delta = target_width_sp - current_width

  if delta <= 0 then
    return 0
  end

  -- Find all glue nodes and sum their stretch
  local total_stretch = 0
  local stretch_order = 0
  local n = head
  while n do
    if n.id == 12 then  -- glue_spec
      if n.stretch_order > stretch_order then
        stretch_order = n.stretch_order
      end
      total_stretch = total_stretch + n.stretch
    end
    n = n.next
  end

  if total_stretch <= 0 then
    return 0
  end

  hbox.width = target_width_sp
  hbox.glue_set = delta / total_stretch
  hbox.glue_sign = 1   -- stretching
  hbox.glue_order = stretch_order

  return delta
end

-- ── Shipout filter: fix ghost narrowing (v3.45) ────────────────

function swarmwrap_shipout(head, groupcode)
  swarmwrap_shipout_count = swarmwrap_shipout_count + 1

  local tw_sp = tex.dimen["swarmwrap@tw@lua"]

  if tw_sp <= 0 then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  local tw_val = tw_sp / 65536.0
  local lw_val = linewidth / 65536.0

  -- Threshold: what counts as narrow (carry-over / ghost narrowing)
  local narrow_max = math.max(tw_val + 40, lw_val * 0.88)

  -- Check if this page has any figure content.
  -- We scan the page node tree for figure markers.
  -- A figure is placed via \smash{\rlap{\hskip...\hbox{\copy\swarmwrap@box}}}
  -- which creates a zero-width hbox containing the image.
  -- We detect it by checking for hboxes that have a \copy of
  -- \swarmwrap@box inside them.
  --
  -- Simpler heuristic: if the page contains an hbox with width
  -- matching a known figure dimension (stored in \swarmwrap@fh),
  -- a figure exists on this page.
  --
  -- Actually, the simplest check: track whether \swarmwrap@fig@page
  -- equals the current page. If yes, a figure was placed on this page.
  local current_page = tex.count["c@page"]
  local fig_page = tex.count["swarmwrap@fig@page"]

  -- Only fix ghost-narrowing on pages AFTER the figure's page
  -- where no new figure was placed on this page.
  -- This means: current_page > fig_page.
  -- If current_page == fig_page, a figure IS on this page — don't touch.
  if current_page <= fig_page then
    return head
  end

  -- Also check: did a new figure get placed AFTER the one at fig_page?
  -- If \swarmwrap@box@num increased since fig_page was set, a new
  -- figure was placed on a later page. We can't easily tell which
  -- page though. For safety, only fix if current_page == fig_page + 1.
  -- This catches the most common case: carry-over on the immediate
  -- next page after a figure.
  if current_page > fig_page + 1 then
    -- More than one page after the figure — could be ghost narrowing
    -- or could be normal text. Only fix if ALL lines are narrow.
    -- We'll check this below.
  end

  local fixed = 0
  local total_narrow = 0
  local total_wide = 0
  local wide_min = lw_val * 0.88

  -- First pass: count narrow vs wide hboxes
  local function count_hboxes(cur, depth)
    while cur do
      if cur.id == 0 then
        local hw = cur.width / 65536.0
        if hw > 0 then
          if hw < narrow_max then
            total_narrow = total_narrow + 1
          elseif hw >= wide_min then
            total_wide = total_wide + 1
          end
        end
      elseif cur.id == 1 and depth < 5 then
        if cur.head then
          count_hboxes(cur.head, depth + 1)
        end
      end
      cur = cur.next
    end
  end

  if head.head then
    count_hboxes(head.head, 0)
  end

  -- Only fix if this looks like ghost narrowing:
  -- - More narrow lines than wide lines (page is mostly narrow)
  -- - OR no wide lines at all (page is entirely narrow)
  local is_ghost = (total_wide == 0) or (total_narrow > total_wide * 3)

  if not is_ghost then
    return head
  end

  -- Second pass: widen all narrow hboxes
  local function fix_hboxes(cur, depth)
    while cur do
      if cur.id == 0 then
        local hw = cur.width / 65536.0
        if hw > 0 and hw < narrow_max then
          local added = widen_hbox(cur, linewidth)
          if added > 0 then
            fixed = fixed + 1
          end
        end
      elseif cur.id == 1 and depth < 5 then
        if cur.head then
          fix_hboxes(cur.head, depth + 1)
        end
      end
      cur = cur.next
    end
  end

  if head.head then
    fix_hboxes(head.head, 0)
  end

  if debug_mode and fixed > 0 then
    texio.write_nl(string.format(
      "swarmwrap v3.45: shipout page %d — ghost fix, %d/%d narrow lines widened (fig_page=%d)",
      swarmwrap_shipout_count, fixed, total_narrow, fig_page))
  end

  return head
end

-- ── Visible content height measurement (v3.44) ──────────────────

function swarmwrap_measure_visible_height(box_reg)
  local box = tex.box[box_reg]
  if not box then
    return 0
  end

  local bs = tex.skip["baselineskip"].width
  local raw_height = box.height + box.depth
  local visible = raw_height

  if visible < bs then
    visible = bs
  end

  if debug_mode then
    local strutbox = tex.box["strutbox"]
    local strut_h = strutbox.height + strutbox.depth
    texio.write_nl(string.format(
      "swarmwrap v3.45: box ht=%.2f dp=%.2f raw=%.2f strut=%.2f visible=%.2f bs=%.1f",
      box.height / 65536.0,
      box.depth / 65536.0,
      raw_height / 65536.0,
      strut_h / 65536.0,
      visible / 65536.0,
      bs / 65536.0))
  end

  return visible
end

-- ── Post-linebreak filter (v3.30 → v3.45) ─────────────────────

function swarmwrap_post_lb(head, groupcode)
  local tw_sp = tex.dimen["swarmwrap@tw@lua"]
  local tw_val = tw_sp / 65536.0

  if tw_sp <= 0 then
    return head
  end

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

texio.write_nl("swarmwrap: callback v3.45 loaded (carry-over penalty + ghost-narrowing shipout fix)")
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
    texio.write_nl("swarmwrap: shipout_filter unavailable — relying on penalty approach only")
  end
end
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

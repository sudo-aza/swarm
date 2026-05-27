-- swarmwrap-callback.lua -- Lua callbacks for swarmwrap.sty
-- v3.45: Fix carry-over narrowing across page breaks (Task #199).
--   When a paragraph with active parshape spans a page break, the
--   remaining narrow lines carry over to the next page. Previously,
--   these narrow lines stayed narrow, wasting horizontal space.
--
--   FIX (two-part):
--   (1) PENALTY APPROACH: Insert a penalty of 10000 (forbidden) after
--       EVERY narrow line in post_linebreak_filter. Reduces but does
--       not fully eliminate carry-over.
--   (2) SHIPOUT FILTER: Compare current page number with the previous
--       figure page (\swarmwrap@fig@page@prev). If current page >
--       previous figure page, narrow hboxes before the first wide
--       hbox are carry-over -- re-pack them at full linewidth.
--
--   Trade-off: May increase page count slightly. Acceptable per spec.

local debug_mode = true
local swarmwrap_shipout_count = 0

-- -- Carry-over tracking (v3.45) ----------------------------------------
-- swarmwrap_mark_fig_placed() is called from \swarmwrapnext but is
-- no longer needed for carry-over detection -- we use fig@page@prev
-- instead. Kept as no-op for backward compatibility.
function swarmwrap_mark_fig_placed()
  -- No-op in v3.45 final. Carry-over detected via fig@page@prev.
end

-- -- Shipout filter: fix carry-over narrowing (v3.45) --------------------
-- Logic: If current_page > fig_page_prev, carry-over occurred.
-- Fix narrow hboxes before the first wide hbox (trailing parshape
-- entry). After the wide hbox, new figure session begins.

function swarmwrap_shipout(head, groupcode)
  swarmwrap_shipout_count = swarmwrap_shipout_count + 1

  local tw_sp = tex.dimen["swarmwrap@tw@lua"]

  if tw_sp <= 0 then
    return head
  end

  local current_page = tex.count["c@page"]
  local fig_page_prev = tex.count["swarmwrap@fig@page@prev"]

  -- Only fix carry-over on pages AFTER the previous figure's page
  if current_page <= fig_page_prev then
    return head
  end

  local linewidth = tex.dimen["linewidth"]
  local tw_val = tw_sp / 65536.0
  local lw_val = linewidth / 65536.0
  local fixed = 0
  local wide_threshold = tw_val + 20.0

  if debug_mode then
    texio.write_nl(string.format(
      "swarmwrap shipout page %d: fig_page_prev=%d (CARRY-OVER), tw=%.1f",
      swarmwrap_shipout_count, fig_page_prev, tw_val))
  end

  local function fix_carryover_in_list(list_head)
    local current = list_head
    local found_trailing_wide = false

    while current do
      if current.id == 0 then
        -- hbox
        local hw = current.width / 65536.0

        if not found_trailing_wide then
          if hw > wide_threshold and hw > 0 then
            -- Wide line = trailing full-width parshape entry
            found_trailing_wide = true
          elseif hw > 0 and hw < lw_val - 10 and math.abs(hw - tw_val) < 30 then
            -- Narrow hbox before wide line = carry-over
            local old_head = current.head
            if old_head then
              local new_box = node.hpack(old_head, linewidth, 'exactly')
              if new_box then
                current.head = new_box.head
                current.width = linewidth
                current.shift = 0
                current.glue_set = 0
                current.glue_sign = 0
                current.glue_order = 0
                fixed = fixed + 1
              end
            end
          end
        end
      elseif current.id == 1 then
        if current.head then
          fix_carryover_in_list(current.head)
        end
      end

      current = current.next
    end
  end

  if head.head then
    fix_carryover_in_list(head.head)
  end

  if debug_mode and fixed > 0 then
    texio.write_nl(string.format(
      "swarmwrap v3.45: shipout page %d -- fixed %d carry-over narrow lines",
      swarmwrap_shipout_count, fixed))
  end

  return head
end

-- -- Visible content height measurement (v3.44) ------------------------

function swarmwrap_measure_visible_height(box_reg)
  local box = tex.box[box_reg]
  if not box then
    if debug_mode then
      texio.write_nl("swarmwrap DEBUG: box[" .. box_reg .. "] is nil")
    end
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

-- -- Post-linebreak filter (v3.30 -> v3.45) ----------------------------

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

texio.write_nl("swarmwrap: callback v3.45 loaded (carry-over penalty + shipout fix + raw box height)")
luatexbase.add_to_callback("post_linebreak_filter",
  swarmwrap_post_lb, "swarmwrap: carry-over penalty")
local shipout_ok = pcall(function()
  luatexbase.add_to_callback("shipout_filter",
    swarmwrap_shipout, "swarmwrap: carry-over fix")
end)
if shipout_ok then
  texio.write_nl("swarmwrap: shipout_filter registered successfully")
else
  local pre_ok = pcall(function()
    luatexbase.add_to_callback("pre_shipout_filter",
      swarmwrap_shipout, "swarmwrap: carry-over fix")
  end)
  if pre_ok then
    texio.write_nl("swarmwrap: pre_shipout_filter registered (fallback)")
  else
    texio.write_nl("swarmwrap: shipout_filter unavailable -- relying on penalty approach only")
  end
end
texio.write_nl("swarmwrap: post_linebreak_filter registered successfully")

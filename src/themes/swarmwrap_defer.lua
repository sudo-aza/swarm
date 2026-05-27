-- swarmwrap_defer.lua — Deferred figure placement helpers (loaded via dofile)
--
-- These functions persist in the global Lua state across \directlua calls,
-- unlike inline \directlua{...} blocks inside \if...\fi conditionals which
-- can silently fail to register in some LuaTeX scoping contexts.
--
-- Called from swarmwrap.sty v3.14.

local swarmwrap_boxes = {}
local counter = 0

function swarmwrap_defer_save()
  counter = counter + 1
  local idx = counter
  local src = tex.box["swarmwrap@box"]
  swarmwrap_boxes[idx] = node.copy(src)
  tex.count["swarmwrap@did"] = idx
end

function swarmwrap_defer_restore(idx)
  local saved = swarmwrap_boxes[idx]
  if saved then
    tex.box["swarmwrap@deferbox"] = node.copy(saved)
  end
end

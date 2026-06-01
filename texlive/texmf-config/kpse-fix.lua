-- kpse-fix.lua: Patch kpse.find_file to use kpsewhich as fallback.
-- This is needed because kpse.find_file inside LuaTeX sometimes returns nil
-- even when the file exists (TeX Live installation issue).
-- Load this BEFORE any packages via \directlua{require("kpse-fix")}

local orig_find_file = kpse.find_file

kpse.find_file = function(name, ...)
  local result = orig_find_file(name, ...)
  if result then return result end
  -- Fallback: use kpsewhich from the shell
  local handle = io.popen('kpsewhich "' .. name .. '" 2>/dev/null', 'r')
  if handle then
    local path = handle:read('*l')
    handle:close()
    if path and #path > 0 then
      return path
    end
  end
  return nil
end

return true

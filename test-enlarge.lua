-- buildpage_filter test: inject \enlargethispage via Lua token API
local n = 0
local enlarge_count = 0

luatexbase.add_to_callback("buildpage_filter", function(cat)
  n = n + 1
  if cat == "penalty" and enlarge_count < 3 then
    enlarge_count = enlarge_count + 1
    -- Create tokens for: \enlargethispage{2\baselineskip}
    local enl = token.create("enlargethispage")
    local lbrace = token.create("{")
    local num2 = token.create("2")
    local bs = token.create("baselineskip")
    local rbrace = token.create("}")
    token.put_next(enl, lbrace, num2, bs, rbrace)
    texio.write_nl("BPF" .. n .. " INJECTED enlargethispage{2bs} (count=" .. enlarge_count .. ")")
  end
  return false
end, "test enlarge")

texio.write_nl("BPF enlargethispage registered")

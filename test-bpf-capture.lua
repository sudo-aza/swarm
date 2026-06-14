local n = 0
local function register_bpf()
  luatexbase.add_to_callback("buildpage_filter", function(cat)
    n = n + 1
    if n <= 30 then
      local ok, err = pcall(function()
        tex.run("\\global\\dimen255=\\pagegoal\\relax")
        tex.run("\\global\\dimen254=\\pagetotal\\relax")  
      end)
      local pg = tex.dimen[255]
      local pt = tex.dimen[254]
      texio.write_nl(string.format("BPF%d cat=%-12s pg=%8.1fpt pt=%8.1fpt ok=%s",
        n, tostring(cat), pg/65536, pt/65536, tostring(ok)))
    end
    return false
  end, "test bpf capture")
  texio.write_nl("BPF registered with tex.run capture")
end
register_bpf()

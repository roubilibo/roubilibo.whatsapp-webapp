-- Managed loader template; add this to ~/.config/hypr/bindings.lua manually.
do
  local home = os.getenv("HOME") or ""
  local plugin = home
    .. "/.config/omarchy/plugins/roubilibo.whatsapp-companion/plugin/hypr/plugin.lua"
  local file = io.open(plugin, "r")
  if file then
    file:close()
    pcall(dofile, plugin)
  end
end

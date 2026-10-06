-- Managed loader added to ~/.config/hypr/bindings.lua by install.sh.
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

-- WhatsApp Hyprland integration entry point.
if rawget(_G, "__roubilibo_whatsapp_companion_loaded") then
  return true
end
_G.__roubilibo_whatsapp_companion_loaded = true

local home = os.getenv("HOME") or ""
local hypr_dir = home .. "/.config/omarchy/plugins/roubilibo.whatsapp-companion/plugin/hypr"

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window / stop Waydroid session",
  hypr_dir .. "/waydroid-aware-close")
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Toggle WhatsApp", hypr_dir .. "/toggle-whatsapp")

-- Keep WhatsApp tiled and let the active workspace layout choose its size.
o.window("^chrome-web[.]whatsapp[.]com__-Default$", {
  tile = true,
  tag = "-default-opacity",
  opacity = "1 1",
})

-- WhatsApp changes its initial webapp title to "WhatsApp call" after opening
-- a call window. Keep call windows tiled with the same sizing behavior.
hl.on("window.title", function(window)
  if not window
    or window.class ~= "chrome-web.whatsapp.com__-Default"
    or window.title ~= "WhatsApp call"
  then
    return
  end

  hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+whatsapp-call" }))
end)

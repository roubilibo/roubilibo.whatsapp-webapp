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

-- Keep WhatsApp's window placement and call behavior with its keybindings.
local border = hl.get_config("general.border_size") or 0
local top_bar = 26

o.window("^chrome-web[.]whatsapp[.]com__-Default$", {
  float = true,
  size = {
    "(monitor_w*0.5-" .. tostring(border * 2) .. ")",
    "(monitor_h-" .. tostring(top_bar + border * 2) .. ")",
  },
  move = {
    tostring(border),
    tostring(top_bar + border),
  },
  tag = "-default-opacity",
  opacity = "1 1",
})

-- WhatsApp changes its initial webapp title to "WhatsApp call" after opening
-- a call window. Keep the existing floating, pinned call-window behavior.
hl.on("window.title", function(window)
  if not window
    or window.class ~= "chrome-web.whatsapp.com__-Default"
    or window.title ~= "WhatsApp call"
  then
    return
  end

  for _, action in ipairs({
    hl.dsp.window.float({ window = window, action = "on" }),
    hl.dsp.window.pin({ window = window, action = "on" }),
    hl.dsp.window.resize({ window = window, x = 400, y = 640, relative = false }),
    hl.dsp.window.tag({ window = window, tag = "+whatsapp-call" }),
  }) do
    hl.dispatch(action)
  end
end)

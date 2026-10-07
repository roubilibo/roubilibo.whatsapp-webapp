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

-- WhatsApp changes its initial webapp title to "WhatsApp call" after opening
-- a call window. Float the pop-out at the size of the current call window.
hl.on("window.title", function(window)
  if not window
    or window.class ~= "chrome-web.whatsapp.com__-Default"
    or window.title ~= "WhatsApp call"
  then
    return
  end

  for _, action in ipairs({
    hl.dsp.window.tag({ window = window, tag = "+whatsapp-call" }),
    hl.dsp.window.float({ window = window, action = "on" }),
    hl.dsp.window.resize({ window = window, x = 406, y = 684, relative = false }),
  }) do
    hl.dispatch(action)
  end
end)

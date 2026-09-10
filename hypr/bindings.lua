-- Add to ~/.config/hypr/bindings.lua after installing the scripts.
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window / stop Waydroid session", "~/.local/bin/whatsapp-companion-aware-close")
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Toggle WhatsApp", "~/.local/bin/whatsapp-companion-toggle")

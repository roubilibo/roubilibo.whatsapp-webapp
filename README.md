# Roubilibo WhatsApp Webapp

An Omarchy bar plugin for WhatsApp Web. The plugin is community software and
is not affiliated with or endorsed by WhatsApp or Meta.

Portable source for the local Omarchy WhatsApp integration:

- bar widget with a theme-colored WhatsApp icon;
- badge showing WhatsApp Web's global unread-list number;
- Chromium MV3 extension using Native Messaging;
- bundled WhatsApp Slim extension, kept separate from the unread bridge;
- `Super+Shift+W` toggle behavior;
- `Super+W` hide/close behavior;
- right-click menu with Close WhatsApp and Restart WhatsApp actions;
- `special:whatsapp` used only as the hidden storage workspace.
- external webapp links are handled by the separate CLOE PWA-link extension
  and opened through the system default browser.
## Demo


https://github.com/user-attachments/assets/a2700fcc-2157-4d13-a0eb-e39df6f9411b


## Install

Install the Omarchy bar widget from the public repository:

```bash
omarchy plugin add https://github.com/roubilibo/roubilibo.whatsapp-webapp.git --enable
```

## Manual installation

The script installs only the Chromium extensions and the native host required
by the unread bridge. Install the bar widget separately with the Omarchy command
above. To install the extensions manually:

```bash
git clone https://github.com/roubilibo/roubilibo.whatsapp-webapp.git
cd roubilibo.whatsapp-webapp
./scripts/check.sh
./scripts/install.sh
```

After installing the bar widget and extensions, add this loader to
`~/.config/hypr/bindings.lua` to enable the WhatsApp keybindings and window
behavior:

```lua
-- BEGIN roubilibo.whatsapp-companion
-- Add this managed loader to ~/.config/hypr/bindings.lua.
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
-- END roubilibo.whatsapp-companion
```

Then run `hyprctl reload`, reload **Local WhatsApp Unread Bridge** in
`chrome://extensions`, and restart WhatsApp Web once.

To also install CLOE for routing webapp links to the system default browser,
use the explicit option:

```bash
./scripts/install.sh --with-cloe
```

`scripts/install.sh` changes Chromium extension settings under `~/.config/`
and installs the unread native host under `~/.local/bin/`. It does not install
the bar widget or edit Hyprland configuration. With `--with-cloe`, it also
downloads the pinned CLOE release from its upstream GitHub repository.

The installer does not install CLOE automatically. If you want external links
from webapps to open in the system default browser, pass the explicit option
after reviewing the script:

This invokes `scripts/install-cloe.sh`; it does not create URL rules.
Configure CLOE in
`chrome://extensions` → CLOE → Extension options. For example, to route
links from a webapp to the default browser, add a matching URL rule such as:

```regex
^https://example\.com/
```

The CLOE installer uses the pinned `v0.1.0` release and repository-controlled
SHA-256 digests for the extension and each supported Linux host architecture.
It rejects unpinned `CLOE_VERSION` overrides before downloading anything.

The installer backs up the Chromium flags file before changing it. The loader
above points to the plugin files installed by Omarchy.

### Reload the Chromium extension after an update

After updating this integration, Chromium can retain an older service worker.
Open `chrome://extensions`, enable Developer mode if needed, find **Local
WhatsApp Unread Bridge**, and click Reload. Then restart the WhatsApp Web app.
This ensures the unread bridge uses the newly installed code.

## Local checks

Before publishing or updating, run:

```bash
./scripts/check.sh
```

This validates shell and JSON syntax, Omarchy's plugin manifest, the minimal
extension permission set, and an uninstall simulation in a temporary home
directory. The simulation confirms unrelated Omarchy plugins and Chromium
extension entries remain intact.

## Behavior

`Super+Shift+W`:

- opens WhatsApp Web if no instance exists;
- restores it from `special:whatsapp` to the current workspace;
- hides the focused WhatsApp window into `special:whatsapp` otherwise;
- focuses an existing visible WhatsApp window when it is not focused.

`Super+W`:

- moves active WhatsApp to `special:whatsapp` instead of closing it;
- restores it when invoked while WhatsApp is in the special workspace;
- retains the existing Waydroid-stop and normal-close behavior for other windows.

WhatsApp and its call windows open tiled. Their size follows the active
workspace layout.

Right-clicking the bar icon opens a small menu with:

- `Close WhatsApp`, which closes all WhatsApp Web windows;
- `Restart WhatsApp`, which closes them and launches WhatsApp Web again.

## Files

`plugin/` contains the Omarchy bar widget and its `hypr/` integration: one Lua
module owns the WhatsApp bindings and window behavior, alongside the helper
commands. Install the plugin through Omarchy so these files are available at
the path used by the loader. `extension/local-whatsapp-bridge/` contains the unread bridge, and
`extension/whatsapp-slim/` contains the separate compact-layout extension;
both are loaded into the Chromium webapp through `--load-extension`.
`native-host/` contains the Native Messaging helper and manifest template; the
host executable remains in `~/.local/bin/` because Chromium's Native Messaging
manifest points to an executable path.

The WhatsApp unread extension only sends a numeric unread value to its local
native host; it does not send chat names, message text, contacts, or account
data. Link routing is handled separately by [CLOE](https://github.com/iltumio/cloe)
using rules configured through its GUI.

Shout-out to [iltumio](https://github.com/iltumio) for creating and maintaining
[CLOE](https://github.com/iltumio/cloe), the external-link helper used by this
integration.

## Remove

Remove the shell plugin with:

```bash
omarchy plugin remove roubilibo.whatsapp-companion --yes
```

To remove the complete integration, including the Omarchy bar plugin installed
separately and the marked Hyprland loader, run:

```bash
./scripts/uninstall.sh
```

Use `--yes` for non-interactive use. CLOE is preserved by default; add
`--with-cloe` only if it was installed for this integration and should also be
removed:

```bash
./scripts/uninstall.sh --with-cloe --yes
```

The uninstall script removes the Omarchy plugin, Chromium extensions, unread
bridge native host, native-host manifest, Chromium extension entries, and
marked WhatsApp snippets such as the loader added manually to `bindings.lua`.
It also removes CLOE only when `--with-cloe` is supplied. The script creates
timestamped backups before editing existing user configuration.

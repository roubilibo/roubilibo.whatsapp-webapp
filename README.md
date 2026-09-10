# Roubilibo WhatsApp Webapp

An Omarchy bar plugin for WhatsApp Web. The plugin is community software and
is not affiliated with or endorsed by WhatsApp or Meta.

Portable source for the local Omarchy WhatsApp integration:

- bar widget with a theme-colored WhatsApp icon;
- badge showing WhatsApp Web's global unread-list number;
- Chromium MV3 extension using Native Messaging;
- `Super+Shift+W` toggle behavior;
- `Super+W` hide/close behavior;
- right-click menu with Close WhatsApp and Restart WhatsApp actions;
- `special:whatsapp` used only as the hidden storage workspace.
- external webapp links are handled by the separate CLOE PWA-link extension
  and opened through the system default browser.

## Install

From this directory:

```bash
./scripts/install.sh
```

For a normal Omarchy plugin installation, use the repository URL:

```bash
omarchy plugin add https://github.com/roubilibo/roubilibo.whatsapp-webapp.git --enable
```

The marketplace installation only installs the shell plugin. The optional
`scripts/install.sh` additionally installs the unread bridge, Chromium
extension, Hyprland helper scripts, and CLOE. Review that script before using
it; it changes files under `~/.config/` and `~/.local/bin/` and downloads the
pinned CLOE release from its upstream GitHub repository.

The installer does not install CLOE automatically. If you want external links
from webapps to open in the system default browser, pass the explicit option
after reviewing the script:

```bash
./scripts/install.sh --with-cloe
```

This invokes `scripts/install-cloe.sh`; it does not create URL rules.
Configure CLOE in
`chrome://extensions` → CLOE → Extension options. For example, to route
links from a webapp to the default browser, add a matching URL rule such as:

```regex
^https://example\.com/
```

The CLOE installer verifies the SHA-256 digests published by GitHub for the
selected CLOE release before installing its extension and native host.

The installer backs up edited user files before changing them. It installs the
bar plugin, extension, native host, and scripts; it adds marked Hyprland
snippets when they are missing and places the widget in the right bar section.

Then apply the Hyprland and shell configuration:

```bash
hyprctl reload
omarchy-shell shell rescanPlugins
```

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

Right-clicking the bar icon opens a small menu with:

- `Close WhatsApp`, which closes all WhatsApp Web windows;
- `Restart WhatsApp`, which closes them and launches WhatsApp Web again.

## Files

`plugin/` is the Omarchy bar plugin. `extension/` is loaded into the
Chromium webapp through `--load-extension`. `native-host/` contains the
Native Messaging helper and manifest template. `hypr/` contains the scripts
and configuration snippets. `PROMPT.md` contains a reusable implementation
prompt for another machine.

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

To remove the complete integration installed by `scripts/install.sh`, run:

```bash
./scripts/uninstall.sh
```

Use `--yes` for non-interactive use. CLOE is preserved by default; add
`--with-cloe` only if it was installed for this integration and should also be
removed:

```bash
./scripts/uninstall.sh --with-cloe --yes
```

The uninstall script removes the separately installed bridge, helper scripts,
native-host manifest, Chromium extension entry, and marked WhatsApp snippets.
It creates timestamped backups before editing existing user configuration.

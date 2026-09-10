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
- external Threads links are handled by the separate CLOE PWA-link extension
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

The installer does not install CLOE automatically. If you want the separate
Threads link integration, run `./scripts/install-cloe.sh` after reviewing it.
It intentionally does not create URL rules. Configure CLOE in
`chrome://extensions` → CLOE → Extension options. For Threads, add:

```regex
^https://(www\.)?threads\.com/
```

The installer backs up edited user files before changing them. It installs the
bar plugin, extension, native host, and scripts, then prints the small binding
and bar-layout snippets that must be merged into the local Omarchy config.

After merging the snippets:

```bash
hyprctl reload
omarchy-shell shell rescanPlugins
```

Restart the WhatsApp Web app once so Chromium loads the extension.

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

## Remove

Remove the shell plugin with:

```bash
omarchy plugin remove roubilibo.whatsapp-webapp --yes
```

If `scripts/install.sh` was used, remove its separately installed bridge,
helper scripts, native-host manifest, Chromium extension entry, and the marked
WhatsApp snippets from the user configuration. The installer creates timestamped
backups before editing existing user files.

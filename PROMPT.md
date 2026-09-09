# Reusable implementation prompt

Copy the prompt below when asking an agent to reproduce this setup on another
Omarchy machine:

```text
Set up a local Omarchy integration for WhatsApp Web.

Requirements:

1. Create an Omarchy bar widget named `roubilibo.whatsapp-webapp` in the
   right bar section. Use the theme foreground color for the WhatsApp icon,
   matching the size of standard bar glyphs (13 px). Show a red badge only
   when the global WhatsApp Web unread-list number is greater than zero.

2. Add a Chromium MV3 extension loaded only on `https://web.whatsapp.com/*`.
   It must use Native Messaging and send only `{unread: number}` to a local
   host named `com.roubilibo.whatsapp_unread`. Read the single global badge
   shown by WhatsApp Web (not the sum of unread messages and not group-chat
   counters). Include robust fallbacks for the title, global unread badge,
   and a visible standalone number outside chat rows. Do not collect message
   text, contact names, or URLs.

3. Install the native host under `~/.config/chromium/NativeMessagingHosts/`
   and store state atomically at
   `~/.local/state/omarchy/whatsapp-unread.json`.

4. Implement `~/.local/bin/toggle-whatsapp` for class
   `chrome-web.whatsapp.com__-Default`:
   - if absent, launch `https://web.whatsapp.com/` normally;
   - if in `special:whatsapp`, restore it to the current workspace and focus;
   - if focused in a normal workspace, move it silently to
     `special:whatsapp`;
   - otherwise focus the existing window.

5. Implement `~/.local/bin/waydroid-aware-close`:
   - if the active window is WhatsApp, move it to `special:whatsapp`;
   - if active WhatsApp is already in that special workspace, restore/toggle
     it;
   - if active window is Waydroid, stop its session;
   - otherwise close the active window.

6. Bind:
   - `Super+Shift+W` to `toggle-whatsapp`;
   - `Super+W` to `waydroid-aware-close`.
   Remove conflicting bindings first. Add a WhatsApp window rule with
   `opacity = "1.0 1.0"` and tag `-default-opacity` so inactive WhatsApp is
   fully opaque.

7. Preserve existing user configuration, create backups before edits, use
   the installed Omarchy APIs, and verify with `hyprctl configerrors`, bar
   plugin reload, extension loading, and the native state file.

8. Do not implement a custom WhatsApp click/window.open interceptor. Install
   the CLOE Chromium PWA-link extension separately and configure the regex
   `^https://(www\\.)?threads\\.com/` so Threads links are opened through the
   system default browser. Keep the WhatsApp unread extension limited to the
   unread badge bridge.
```

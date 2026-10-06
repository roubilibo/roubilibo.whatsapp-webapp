#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

fail() {
  echo "Check failed: $*" >&2
  exit 1
}

for command in bash jq omarchy python3 rg; do
  command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done

bash -n "$repo_dir"/scripts/*.sh \
  "$repo_dir"/plugin/hypr/toggle-whatsapp \
  "$repo_dir"/plugin/hypr/close-whatsapp \
  "$repo_dir"/plugin/hypr/restart-whatsapp \
  "$repo_dir"/plugin/hypr/waydroid-aware-close
jq empty "$repo_dir/manifest.json" \
  "$repo_dir/extension/local-whatsapp-bridge/manifest.json" \
  "$repo_dir/extension/whatsapp-slim/manifest.json" \
  "$repo_dir/native-host/com.roubilibo.whatsapp_unread.json.in"
jq -e '.permissions == ["nativeMessaging"]' \
  "$repo_dir/extension/local-whatsapp-bridge/manifest.json" >/dev/null || fail "extension permissions expanded"
jq -e '.name == "WhatsApp Slim" and .content_scripts[0].css == ["whatsapp.css"] and .content_scripts[0].js == ["system-theme.js"]' \
  "$repo_dir/extension/whatsapp-slim/manifest.json" >/dev/null || \
  fail "bundled WhatsApp Slim manifest is invalid"
rg -F -- 'flex: 0 0 280px' "$repo_dir/extension/whatsapp-slim/whatsapp.css" >/dev/null || \
  fail "bundled WhatsApp Slim is not set to 280px"
rg -F -- 'border-left: none !important' "$repo_dir/extension/whatsapp-slim/whatsapp.css" >/dev/null || \
  fail "bundled WhatsApp Slim divider override is missing"
rg -F -- 'extension_sha256=7a0fd8f372bc46feb69a14f7a24246b620517e0ef7cff91444fea7cbb8a49143' \
  "$repo_dir/scripts/install-cloe.sh" >/dev/null || fail "CLOE extension digest is not pinned"
rg -F -- 'host_sha256=3ced48991fad67986f5aab2581802af0b546b60785d8b26b479129197da546e9' \
  "$repo_dir/scripts/install-cloe.sh" >/dev/null || fail "CLOE x86_64 digest is not pinned"
rg -F -- 'host_sha256=fb5c4f656bf3ee9111345223f63f63ac0f7d7f9f378cc310327bf78ebef6eff5' \
  "$repo_dir/scripts/install-cloe.sh" >/dev/null || fail "CLOE aarch64 digest is not pinned"
if CLOE_VERSION=v9.9.9 HOME="$test_home" "$repo_dir/scripts/install-cloe.sh" >/dev/null 2>&1; then
  fail "CLOE installer accepted an unpinned version"
fi
omarchy plugin validate "$repo_dir"

install_home="$test_home/install.home"
install -d "$install_home/.config/omarchy/plugins/roubilibo.whatsapp-companion" \
  "$install_home/.config/hypr"
printf 'plugin must remain untouched\n' \
  > "$install_home/.config/omarchy/plugins/roubilibo.whatsapp-companion/sentinel"
plugin_dir="$install_home/.config/omarchy/plugins/roubilibo.whatsapp-companion"
find "$plugin_dir" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "$test_home/plugin.before"
printf 'keep bindings\n' > "$install_home/.config/hypr/bindings.lua"
printf 'keep window rules\n' > "$install_home/.config/hypr/windows.lua"
printf '%s\n' '--load-extension=/opt/keep' > "$install_home/.config/chromium-flags.conf"
HOME="$install_home" "$repo_dir/scripts/install.sh"

extension_dir="$install_home/.config/omarchy/chromium/extensions/whatsapp-companion"
slim_extension_dir="$install_home/.config/omarchy/chromium/extensions/whatsapp-slim"
[[ -f "$extension_dir/manifest.json" ]] || fail "unread extension was not installed"
[[ -f "$extension_dir/background.js" && -f "$extension_dir/content.js" ]] || \
  fail "unread extension files are incomplete"
[[ -f "$slim_extension_dir/manifest.json" && -f "$slim_extension_dir/whatsapp.css" ]] || \
  fail "WhatsApp Slim extension was not installed"
[[ -x "$install_home/.local/bin/whatsapp-companion-unread-host" ]] || \
  fail "unread native host was not installed"
jq -e '.name == "com.roubilibo.whatsapp_companion" and (.allowed_origins | length == 1)' \
  "$install_home/.config/chromium/NativeMessagingHosts/com.roubilibo.whatsapp_companion.json" \
  >/dev/null || fail "native host manifest is invalid"
rg -F -- '/opt/keep' "$install_home/.config/chromium-flags.conf" >/dev/null || \
  fail "installer removed an unrelated Chromium extension"
rg -F -- "$extension_dir" "$install_home/.config/chromium-flags.conf" >/dev/null || \
  fail "unread extension was not added to Chromium flags"
rg -F -- "$slim_extension_dir" "$install_home/.config/chromium-flags.conf" >/dev/null || \
  fail "WhatsApp Slim was not added to Chromium flags"
[[ "$(cat "$install_home/.config/hypr/bindings.lua")" == 'keep bindings' ]] || \
  fail "installer changed Hyprland bindings"
[[ "$(cat "$install_home/.config/hypr/windows.lua")" == 'keep window rules' ]] || \
  fail "installer changed Hyprland window rules"
[[ -f "$install_home/.config/omarchy/plugins/roubilibo.whatsapp-companion/sentinel" ]] || \
  fail "installer changed the Omarchy plugin directory"
find "$plugin_dir" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "$test_home/plugin.after"
cmp -s "$test_home/plugin.before" "$test_home/plugin.after" || \
  fail "installer modified files in the Omarchy plugin directory"

uninstall_home="$test_home/user.home"
extension_dir="$uninstall_home/.config/omarchy/chromium/extensions/whatsapp-companion"
uninstall_decoy_path="${extension_dir/./X}"
install -d "$uninstall_home/.config/omarchy/plugins/other.plugin"
printf 'keep\n' > "$uninstall_home/.config/omarchy/plugins/other.plugin/keep"
install -d "$uninstall_home/.config/omarchy/plugins/roubilibo.whatsapp-companion"
install -d "$uninstall_home/.config/omarchy/chromium/extensions/whatsapp-companion"
install -d "$uninstall_home/.config/chromium/NativeMessagingHosts"
install -d "$uninstall_home/.config/hypr"
printf '%s\n' \
  '{"bar":{"layout":[[{"id":"other.plugin"},{"id":"roubilibo.whatsapp-companion"}]]},"plugins":[{"id":"other.plugin"},{"id":"roubilibo.whatsapp-companion"}]}' \
  > "$uninstall_home/.config/omarchy/shell.json"
printf '%s\n' \
  'other binding' \
  'o.bind("SUPER + SHIFT + W", "Toggle WhatsApp", "~/.local/bin/toggle-whatsapp")' \
  '-- BEGIN roubilibo.whatsapp-companion' \
  'whatsapp binding' \
  '-- END roubilibo.whatsapp-companion' \
  > "$uninstall_home/.config/hypr/bindings.lua"
printf '%s\n' \
  'other window rule' \
  '-- BEGIN roubilibo.whatsapp-companion' \
  'whatsapp window rule' \
  '-- END roubilibo.whatsapp-companion' \
  > "$uninstall_home/.config/hypr/windows.lua"
printf '%s\n' \
  "--load-extension=$uninstall_decoy_path,/opt/other-extension,$extension_dir" \
  > "$uninstall_home/.config/chromium-flags.conf"

HOME="$uninstall_home" "$repo_dir/scripts/uninstall.sh" --yes

[[ -f "$uninstall_home/.config/omarchy/plugins/other.plugin/keep" ]] || fail "unrelated plugin was removed"
[[ ! -e "$uninstall_home/.config/omarchy/plugins/roubilibo.whatsapp-companion" ]] || fail "plugin directory remains"
jq -e '.bar.layout[0][0].id == "other.plugin" and .plugins[0].id == "other.plugin"' \
  "$uninstall_home/.config/omarchy/shell.json" >/dev/null || fail "shell entries were not isolated"
rg -F -- '~/.local/bin/toggle-whatsapp' "$uninstall_home/.config/hypr/bindings.lua" >/dev/null || \
  fail "unmarked legacy binding was removed"
rg -F -- "$uninstall_decoy_path" "$uninstall_home/.config/chromium-flags.conf" >/dev/null || \
  fail "unrelated dotted-path extension was removed"
rg -F -- '/opt/other-extension' "$uninstall_home/.config/chromium-flags.conf" >/dev/null || \
  fail "unrelated extension was removed"
! rg -F -- "$extension_dir" "$uninstall_home/.config/chromium-flags.conf" >/dev/null || \
  fail "WhatsApp extension flag remains"

if HOME=/ "$repo_dir/scripts/uninstall.sh" --yes >/dev/null 2>&1; then
  fail "unsafe HOME was accepted"
fi
if HOME=/ "$repo_dir/scripts/install.sh" >/dev/null 2>&1; then
  fail "installer accepted unsafe HOME"
fi
if HOME=/ "$repo_dir/scripts/install-cloe.sh" >/dev/null 2>&1; then
  fail "CLOE installer accepted unsafe HOME"
fi

echo "All local checks passed."

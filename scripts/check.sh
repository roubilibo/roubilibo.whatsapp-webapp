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

bash -n "$repo_dir"/scripts/*.sh "$repo_dir"/hypr/*
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
omarchy plugin validate "$repo_dir"

install -d "$test_home/.config/omarchy/plugins/other.plugin"
printf 'keep\n' > "$test_home/.config/omarchy/plugins/other.plugin/keep"
install -d "$test_home/.config/omarchy/plugins/roubilibo.whatsapp-companion"
install -d "$test_home/.config/omarchy/chromium/extensions/whatsapp-companion"
install -d "$test_home/.config/chromium/NativeMessagingHosts"
install -d "$test_home/.config/hypr"
printf '%s\n' \
  '{"bar":{"layout":[[{"id":"other.plugin"},{"id":"roubilibo.whatsapp-companion"}]]},"plugins":[{"id":"other.plugin"},{"id":"roubilibo.whatsapp-companion"}]}' \
  > "$test_home/.config/omarchy/shell.json"
printf '%s\n' \
  'other binding' \
  'o.bind("SUPER + SHIFT + W", "Toggle WhatsApp", "~/.local/bin/toggle-whatsapp")' \
  '-- BEGIN roubilibo.whatsapp-companion' \
  'whatsapp binding' \
  '-- END roubilibo.whatsapp-companion' \
  > "$test_home/.config/hypr/bindings.lua"
printf '%s\n' \
  'other window rule' \
  '-- BEGIN roubilibo.whatsapp-companion' \
  'whatsapp window rule' \
  '-- END roubilibo.whatsapp-companion' \
  > "$test_home/.config/hypr/windows.lua"
printf '%s\n' \
  "--load-extension=/opt/other-extension,$test_home/.config/omarchy/chromium/extensions/whatsapp-companion" \
  > "$test_home/.config/chromium-flags.conf"

HOME="$test_home" "$repo_dir/scripts/uninstall.sh" --yes

[[ -f "$test_home/.config/omarchy/plugins/other.plugin/keep" ]] || fail "unrelated plugin was removed"
[[ ! -e "$test_home/.config/omarchy/plugins/roubilibo.whatsapp-companion" ]] || fail "plugin directory remains"
jq -e '.bar.layout[0][0].id == "other.plugin" and .plugins[0].id == "other.plugin"' \
  "$test_home/.config/omarchy/shell.json" >/dev/null || fail "shell entries were not isolated"
rg -F -- '~/.local/bin/toggle-whatsapp' "$test_home/.config/hypr/bindings.lua" >/dev/null || \
  fail "unmarked legacy binding was removed"
rg -F -- '/opt/other-extension' "$test_home/.config/chromium-flags.conf" >/dev/null || fail "unrelated extension was removed"
! rg -F -- 'whatsapp-companion' "$test_home/.config/chromium-flags.conf" >/dev/null || fail "WhatsApp extension flag remains"

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

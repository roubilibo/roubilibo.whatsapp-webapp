#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
home_dir=${HOME:?HOME is required}
stamp=$(date +%Y%m%d-%H%M%S)
plugin_dir="$home_dir/.config/omarchy/plugins/roubilibo.whatsapp-webapp"
with_cloe=false

case "${1:-}" in
  "") ;;
  --with-cloe) with_cloe=true ;;
  *)
    echo "Usage: $0 [--with-cloe]" >&2
    exit 2
    ;;
esac

if [[ -f "$plugin_dir/manifest.json" ]]; then
  install_mode="update"
else
  install_mode="install"
fi

if [[ "$install_mode" == "update" ]]; then
  echo "Existing WhatsApp plugin detected; updating it."
else
  echo "Installing WhatsApp integration."
fi

if [[ "$with_cloe" == true ]]; then
  "$repo_dir/scripts/install-cloe.sh"
else
  echo "CLOE installation skipped. Use --with-cloe to install it explicitly."
fi

backup_file() {
  local file=$1
  [[ -e "$file" ]] && cp -a -- "$file" "$file.bak.$stamp"
}

install -Dm644 "$repo_dir/plugin/manifest.json" "$plugin_dir/manifest.json"
install -Dm644 "$repo_dir/plugin/Widget.qml" "$plugin_dir/Widget.qml"
install -Dm644 "$repo_dir/plugin/whatsapp.svg" "$plugin_dir/whatsapp.svg"

extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-unread"
install -Dm644 "$repo_dir/extension/manifest.json" "$extension_dir/manifest.json"
install -Dm644 "$repo_dir/extension/background.js" "$extension_dir/background.js"
install -Dm644 "$repo_dir/extension/content.js" "$extension_dir/content.js"

install -Dm755 "$repo_dir/native-host/whatsapp-unread-host.py" "$home_dir/.local/bin/whatsapp-unread-host"
host_dir="$home_dir/.config/chromium/NativeMessagingHosts"
mkdir -p "$host_dir"
sed "s|__HOME__|$home_dir|g" "$repo_dir/native-host/com.roubilibo.whatsapp_unread.json.in" \
  > "$host_dir/com.roubilibo.whatsapp_unread.json"
chmod 644 "$host_dir/com.roubilibo.whatsapp_unread.json"

install -Dm755 "$repo_dir/hypr/toggle-whatsapp" "$home_dir/.local/bin/toggle-whatsapp"
install -Dm755 "$repo_dir/hypr/close-whatsapp" "$home_dir/.local/bin/close-whatsapp"
install -Dm755 "$repo_dir/hypr/restart-whatsapp" "$home_dir/.local/bin/restart-whatsapp"
install -Dm755 "$repo_dir/hypr/waydroid-aware-close" "$home_dir/.local/bin/waydroid-aware-close"

bindings_file="$home_dir/.config/hypr/bindings.lua"
if [[ -e "$bindings_file" ]] && ! grep -Fq 'toggle-whatsapp' "$bindings_file"; then
  backup_file "$bindings_file"
  {
    printf '\n-- BEGIN roubilibo.whatsapp-webapp\n'
    cat "$repo_dir/hypr/bindings.lua"
    printf -- '-- END roubilibo.whatsapp-webapp\n'
  } >> "$bindings_file"
fi

windows_file="$home_dir/.config/hypr/windows.lua"
if [[ -e "$windows_file" ]] && ! grep -Fq 'chrome-web[.]whatsapp' "$windows_file"; then
  backup_file "$windows_file"
  {
    printf '\n-- BEGIN roubilibo.whatsapp-webapp\n'
    cat "$repo_dir/hypr/windows.lua"
    printf -- '-- END roubilibo.whatsapp-webapp\n'
  } >> "$windows_file"
fi

flags_file="$home_dir/.config/chromium-flags.conf"
mkdir -p "$(dirname -- "$flags_file")"
touch "$flags_file"
if ! grep -Fq "$extension_dir" "$flags_file"; then
  backup_file "$flags_file"
  if grep -q '^--load-extension=' "$flags_file"; then
    sed -i "s|^--load-extension=|--load-extension=$extension_dir,|" "$flags_file"
  else
    printf '%s\n' "--load-extension=$extension_dir" >> "$flags_file"
  fi
fi

echo "WhatsApp plugin $install_mode completed."
if command -v omarchy >/dev/null 2>&1; then
  omarchy bar move roubilibo.whatsapp-webapp --section right || true
fi
echo "Then run: hyprctl reload && omarchy-shell shell rescanPlugins"
echo "Restart WhatsApp Web once to load the extension."

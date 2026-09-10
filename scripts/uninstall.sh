#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
home_dir=${HOME:?HOME is required}
stamp=$(date +%Y%m%d-%H%M%S)
remove_cloe=false
assume_yes=false

assert_safe_home() {
  [[ "$home_dir" == /* && "$home_dir" != / ]] || {
    echo "Refusing to use unsafe HOME: $home_dir" >&2
    exit 1
  }
}

assert_managed_path() {
  local path=$1
  case "$path" in
    "$home_dir/.config/omarchy/plugins/"*|\
    "$home_dir/.config/omarchy/chromium/extensions/"*|\
    "$home_dir/.config/chromium/NativeMessagingHosts/"*|\
    "$home_dir/.local/bin/"*|\
    "$home_dir/.local/state/omarchy/"*) ;;
    *)
      echo "Refusing unmanaged path: $path" >&2
      exit 1
      ;;
  esac
}

assert_safe_home

for arg in "$@"; do
  case "$arg" in
    --with-cloe) remove_cloe=true ;;
    --yes) assume_yes=true ;;
    *)
      echo "Usage: $0 [--with-cloe] [--yes]" >&2
      exit 2
      ;;
  esac
done

if [[ "$assume_yes" != true ]]; then
  echo "This removes the WhatsApp Web integration from $home_dir."
  [[ "$remove_cloe" == true ]] && echo "It also removes the separately installed CLOE files."
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

backup_file() {
  local file=$1
  [[ -e "$file" ]] && cp -a -- "$file" "$file.bak.$stamp"
}

remove_block() {
  local file=$1 begin=$2 end=$3 temp
  [[ -f "$file" ]] || return 0
  grep -Fq -- "$begin" "$file" || return 0
  grep -Fq -- "$end" "$file" || return 0
  backup_file "$file"
  temp=$(mktemp)
  awk -v begin="$begin" -v end="$end" '
    index($0, begin) { removing = 1; next }
    removing && index($0, end) { removing = 0; next }
    !removing { print }
  ' "$file" > "$temp"
  install -m "$(stat -c '%a' "$file")" "$temp" "$file"
  if [[ ! -s "$file" ]]; then
    : > "$file"
  fi
  rm -f -- "$temp"
}

remove_whatsapp_window_rule() {
  local file=$1 temp
  [[ -f "$file" ]] || return 0
  grep -Fq -- '-- Keep WhatsApp visibly transparent when unfocused.' "$file" || return 0
  backup_file "$file"
  temp=$(mktemp)
  awk '
    /-- Keep WhatsApp visibly transparent when unfocused\./ { removing = 1; next }
    removing && /^\}\)$/ { removing = 0; next }
    !removing { print }
  ' "$file" > "$temp"
  install -m "$(stat -c '%a' "$file")" "$temp" "$file"
  rm -f -- "$temp"
}

remove_load_extension() {
  local file=$1 extension_dir=$2 temp
  [[ -f "$file" ]] || return 0
  grep -Fq -- "$extension_dir" "$file" || return 0
  backup_file "$file"
  temp=$(mktemp)
  awk -v path="$extension_dir" '
    index($0, "--load-extension=") == 1 {
      sub(path ",", "", $0)
      sub("," path, "", $0)
      if ($0 == "--load-extension=" path) next
    }
    { print }
  ' "$file" > "$temp"
  install -m "$(stat -c '%a' "$file")" "$temp" "$file"
  rm -f -- "$temp"
}

remove_shell_entry() {
  local file=$1 temp
  [[ -f "$file" ]] || return 0
  command -v jq >/dev/null 2>&1 || {
    echo "Warning: jq is unavailable; shell.json was not changed." >&2
    return 0
  }
  temp=$(mktemp)
  jq --arg id "roubilibo.whatsapp-companion" --arg legacy_id "roubilibo.whatsapp-webapp" \
    'del(.bar.layout[]? | .[]? | select(.id == $id))
     | del(.bar.layout[]? | .[]? | select(.id == $legacy_id))
     | del(.plugins[]? | select(.id == $id or .id == $legacy_id))' \
    "$file" > "$temp"
  if ! cmp -s "$file" "$temp"; then
    backup_file "$file"
    install -m "$(stat -c '%a' "$file")" "$temp" "$file"
  fi
  rm -f -- "$temp"
}

plugin_dir="$home_dir/.config/omarchy/plugins/roubilibo.whatsapp-companion"
legacy_plugin_dir="$home_dir/.config/omarchy/plugins/roubilibo.whatsapp-webapp"
extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-companion"
legacy_extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-unread"
flags_file="$home_dir/.config/chromium-flags.conf"
native_dir="$home_dir/.config/chromium/NativeMessagingHosts"

remove_dirs=(
  "$plugin_dir"
  "$legacy_plugin_dir"
  "$extension_dir"
  "$legacy_extension_dir"
)
remove_files=(
  "$home_dir/.local/bin/whatsapp-companion-unread-host"
  "$home_dir/.local/bin/whatsapp-companion-toggle"
  "$home_dir/.local/bin/whatsapp-companion-close"
  "$home_dir/.local/bin/whatsapp-companion-restart"
  "$home_dir/.local/bin/whatsapp-companion-aware-close"
  "$home_dir/.local/bin/whatsapp-unread-host"
  "$home_dir/.local/bin/toggle-whatsapp"
  "$home_dir/.local/bin/close-whatsapp"
  "$home_dir/.local/bin/restart-whatsapp"
  "$home_dir/.local/bin/waydroid-aware-close"
  "$native_dir/com.roubilibo.whatsapp_companion.json"
  "$native_dir/com.roubilibo.whatsapp_unread.json"
  "$home_dir/.local/state/omarchy/whatsapp-companion.json"
  "$home_dir/.local/state/omarchy/whatsapp-companion-debug.log"
  "$home_dir/.local/state/omarchy/whatsapp-unread.json"
  "$home_dir/.local/state/omarchy/whatsapp-unread-debug.log"
)

for path in "${remove_dirs[@]}" "${remove_files[@]}"; do
  assert_managed_path "$path"
done

remove_shell_entry "$home_dir/.config/omarchy/shell.json"
remove_block "$home_dir/.config/hypr/bindings.lua" \
  "-- BEGIN roubilibo.whatsapp-companion" "-- END roubilibo.whatsapp-companion"
remove_block "$home_dir/.config/hypr/windows.lua" \
  "-- BEGIN roubilibo.whatsapp-companion" "-- END roubilibo.whatsapp-companion"
remove_block "$home_dir/.config/hypr/bindings.lua" \
  "-- BEGIN roubilibo.whatsapp-webapp" "-- END roubilibo.whatsapp-webapp"
remove_block "$home_dir/.config/hypr/windows.lua" \
  "-- BEGIN roubilibo.whatsapp-webapp" "-- END roubilibo.whatsapp-webapp"
remove_whatsapp_window_rule "$home_dir/.config/hypr/windows.lua"
remove_load_extension "$flags_file" "$extension_dir"
remove_load_extension "$flags_file" "$legacy_extension_dir"

if [[ "$remove_cloe" == true ]]; then
  assert_managed_path "$home_dir/.config/omarchy/chromium/extensions/cloe"
  assert_managed_path "$native_dir/com.iltumio.cloe.json"
  assert_managed_path "$home_dir/.local/bin/cloe-host"
  remove_load_extension "$flags_file" "$home_dir/.config/omarchy/chromium/extensions/cloe"
  rm -rf -- "$home_dir/.config/omarchy/chromium/extensions/cloe"
  rm -f -- "$home_dir/.config/chromium/NativeMessagingHosts/com.iltumio.cloe.json"
  rm -f -- "$home_dir/.local/bin/cloe-host"
fi

rm -rf -- "${remove_dirs[@]}"
rm -f -- "${remove_files[@]}"

echo "WhatsApp Web integration removed. Restart the shell and Chromium if they are running."

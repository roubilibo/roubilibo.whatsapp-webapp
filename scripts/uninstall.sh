#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
home_dir=${HOME:?HOME is required}
stamp=$(date +%Y%m%d-%H%M%S)
remove_cloe=false
assume_yes=false

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

plugin_dir="$home_dir/.config/omarchy/plugins/roubilibo.whatsapp-webapp"
extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-unread"
flags_file="$home_dir/.config/chromium-flags.conf"
native_dir="$home_dir/.config/chromium/NativeMessagingHosts"

remove_block "$home_dir/.config/hypr/bindings.lua" \
  "-- BEGIN roubilibo.whatsapp-webapp" "-- END roubilibo.whatsapp-webapp"
remove_block "$home_dir/.config/hypr/windows.lua" \
  "-- BEGIN roubilibo.whatsapp-webapp" "-- END roubilibo.whatsapp-webapp"
remove_load_extension "$flags_file" "$extension_dir"

if [[ "$remove_cloe" == true ]]; then
  remove_load_extension "$flags_file" "$home_dir/.config/omarchy/chromium/extensions/cloe"
  rm -rf -- "$home_dir/.config/omarchy/chromium/extensions/cloe"
  rm -f -- "$home_dir/.config/chromium/NativeMessagingHosts/com.iltumio.cloe.json"
  rm -f -- "$home_dir/.local/bin/cloe-host"
fi

rm -rf -- "$plugin_dir" "$extension_dir"
rm -f -- \
  "$home_dir/.local/bin/whatsapp-unread-host" \
  "$home_dir/.local/bin/toggle-whatsapp" \
  "$home_dir/.local/bin/close-whatsapp" \
  "$home_dir/.local/bin/restart-whatsapp" \
  "$home_dir/.local/bin/waydroid-aware-close" \
  "$native_dir/com.roubilibo.whatsapp_unread.json" \
  "$home_dir/.local/state/omarchy/whatsapp-unread.json" \
  "$home_dir/.local/state/omarchy/whatsapp-unread-debug.log"

echo "WhatsApp Web integration removed. Restart the shell and Chromium if they are running."

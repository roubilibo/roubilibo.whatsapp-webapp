#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
home_dir=${HOME:?HOME is required}
stamp=$(date +%Y%m%d-%H%M%S)
with_cloe=false

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

backup_file() {
  local file=$1
  if [[ -e "$file" && ! -e "$file.bak.$stamp" ]]; then
    cp -a -- "$file" "$file.bak.$stamp"
  fi
}

case "${1:-}" in
  "") ;;
  --with-cloe) with_cloe=true ;;
  *)
    echo "Usage: $0 [--with-cloe]" >&2
    exit 2
    ;;
esac

if [[ "$with_cloe" == true ]]; then
  "$repo_dir/scripts/install-cloe.sh"
else
  echo "CLOE installation skipped. Use --with-cloe to install it explicitly."
fi

extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-companion"
slim_extension_dir="$home_dir/.config/omarchy/chromium/extensions/whatsapp-slim"
bridge_source_dir="$repo_dir/extension/local-whatsapp-bridge"
assert_managed_path "$extension_dir"
assert_managed_path "$slim_extension_dir"
assert_managed_path "$home_dir/.local/bin/whatsapp-companion-unread-host"
install -Dm644 "$bridge_source_dir/manifest.json" "$extension_dir/manifest.json"
install -Dm644 "$bridge_source_dir/background.js" "$extension_dir/background.js"
install -Dm644 "$bridge_source_dir/content.js" "$extension_dir/content.js"
install -Dm644 "$repo_dir/extension/whatsapp-slim/manifest.json" "$slim_extension_dir/manifest.json"
install -Dm644 "$repo_dir/extension/whatsapp-slim/system-theme.js" "$slim_extension_dir/system-theme.js"
install -Dm644 "$repo_dir/extension/whatsapp-slim/whatsapp.css" "$slim_extension_dir/whatsapp.css"

install -Dm755 "$repo_dir/native-host/whatsapp-unread-host.py" "$home_dir/.local/bin/whatsapp-companion-unread-host"
host_dir="$home_dir/.config/chromium/NativeMessagingHosts"
assert_managed_path "$host_dir/com.roubilibo.whatsapp_companion.json"
mkdir -p "$host_dir"
extension_id=$(python3 - "$extension_dir/manifest.json" <<'PY'
import base64, hashlib, json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
key = manifest.get("key")
if key:
    digest = hashlib.sha256(base64.b64decode(key)).digest()[:16]
else:
    digest = hashlib.sha256(sys.argv[1].encode()).digest()[:16]
print("".join(chr(97 + ((byte >> shift) & 15))
            for byte in digest for shift in (4, 0)))
PY
)
sed -e "s|__HOME__|$home_dir|g" -e "s|__EXTENSION_ID__|$extension_id|g" \
  "$repo_dir/native-host/com.roubilibo.whatsapp_unread.json.in" \
  > "$host_dir/com.roubilibo.whatsapp_companion.json"
chmod 644 "$host_dir/com.roubilibo.whatsapp_companion.json"

flags_file="$home_dir/.config/chromium-flags.conf"
mkdir -p "$(dirname -- "$flags_file")"
touch "$flags_file"

remove_load_extension_entry() {
  local file=$1 extension_path=$2 temp
  [[ -f "$file" ]] || return 0
  grep -Fq -- "$extension_path" "$file" || return 0
  backup_file "$file"
  temp=$(mktemp)
  awk -v path="$extension_path" '
    index($0, "--load-extension=") == 1 {
      prefix = "--load-extension="
      list = substr($0, length(prefix) + 1)
      count = split(list, entries, ",")
      output = ""
      for (i = 1; i <= count; i++) {
        if (entries[i] == path) continue
        if (output != "") output = output ","
        output = output entries[i]
      }
      if (output != "") print prefix output
      next
    }
    { print }
  ' "$file" > "$temp"
  install -m "$(stat -c '%a' "$file")" "$temp" "$file"
  rm -f -- "$temp"
}

# Use the repo's edited Slim extension instead of the stock copy when it is
# present in the user's Chromium flags.
remove_load_extension_entry \
  "$flags_file" \
  "/usr/share/omarchy/default/chromium/extensions/whatsapp-slim"

if ! grep -Fq "$extension_dir" "$flags_file"; then
  backup_file "$flags_file"
  if grep -q '^--load-extension=' "$flags_file"; then
    sed -i "s|^--load-extension=|--load-extension=$extension_dir,|" "$flags_file"
  else
    printf '%s\n' "--load-extension=$extension_dir" >> "$flags_file"
  fi
fi
if ! grep -Fq "$slim_extension_dir" "$flags_file"; then
  backup_file "$flags_file"
  if grep -q '^--load-extension=' "$flags_file"; then
    sed -i "s|^--load-extension=|--load-extension=$slim_extension_dir,|" "$flags_file"
  else
    printf '%s\n' "--load-extension=$slim_extension_dir" >> "$flags_file"
  fi
fi

echo "WhatsApp Chromium extensions installed."
echo "Add the Hyprland loader from the README if you want the WhatsApp keybindings and window behavior."
echo "Restart WhatsApp Web once to load the extensions."

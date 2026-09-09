#!/usr/bin/env bash
set -euo pipefail

home_dir=${HOME:?HOME is required}
version=${CLOE_VERSION:-v0.1.0}
base_url="https://github.com/iltumio/cloe/releases/download/$version"
extension_dir="$home_dir/.config/omarchy/chromium/extensions/cloe"
native_dir="$home_dir/.config/chromium/NativeMessagingHosts"
flags_file="$home_dir/.config/chromium-flags.conf"
stamp=$(date +%Y%m%d-%H%M%S)

mkdir -p "$extension_dir" "$native_dir" "$(dirname -- "$flags_file")"
curl -fsSL "$base_url/cloe-extension.zip" -o /tmp/cloe-extension.zip
unzip -oq /tmp/cloe-extension.zip -d "$extension_dir"
case "$(uname -m)" in
  x86_64|amd64) host_asset="cloe-host-linux-x86_64" ;;
  aarch64|arm64) host_asset="cloe-host-linux-aarch64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
curl -fsSL "$base_url/$host_asset" -o "$home_dir/.local/bin/cloe-host"
chmod 755 "$home_dir/.local/bin/cloe-host"

extension_id=$(python3 - "$extension_dir" <<'PY'
import hashlib, sys
path = sys.argv[1]
digest = hashlib.sha256(path.encode()).hexdigest()[:32]
print("".join(chr(ord("a") + int(char, 16)) for char in digest))
PY
)

python3 - "$native_dir/com.iltumio.cloe.json" "$home_dir" "$extension_id" <<'PY'
import json, sys
target, home, extension_id = sys.argv[1:]
manifest = {
    "name": "com.iltumio.cloe",
    "description": "CLOE — Open links in external default browser",
    "path": home + "/.local/bin/cloe-host",
    "type": "stdio",
    "allowed_origins": [f"chrome-extension://{extension_id}/"],
}
with open(target, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
PY
chmod 644 "$native_dir/com.iltumio.cloe.json"

touch "$flags_file"
if ! grep -Fq "$extension_dir" "$flags_file"; then
  [[ -e "$flags_file" ]] && cp -a -- "$flags_file" "$flags_file.bak.$stamp"
  if grep -q '^--load-extension=' "$flags_file"; then
    sed -i "s|^--load-extension=|--load-extension=$extension_dir,|" "$flags_file"
  else
    printf '%s\n' "--load-extension=$extension_dir" >> "$flags_file"
  fi
fi

echo "CLOE installed with extension id: $extension_id"
echo "Open chrome://extensions, open CLOE Options, and add your URL regex there."

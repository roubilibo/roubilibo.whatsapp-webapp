#!/usr/bin/env bash
set -euo pipefail

home_dir=${HOME:?HOME is required}
version=${CLOE_VERSION:-v0.1.0}
base_url="https://github.com/iltumio/cloe/releases/download/$version"
api_url="https://api.github.com/repos/iltumio/cloe/releases/tags/$version"
extension_dir="$home_dir/.config/omarchy/chromium/extensions/cloe"
native_dir="$home_dir/.config/chromium/NativeMessagingHosts"
flags_file="$home_dir/.config/chromium-flags.conf"
stamp=$(date +%Y%m%d-%H%M%S)

assert_safe_home() {
  [[ "$home_dir" == /* && "$home_dir" != / ]] || {
    echo "Refusing to use unsafe HOME: $home_dir" >&2
    exit 1
  }
}

assert_managed_path() {
  local path=$1
  case "$path" in
    "$home_dir/.config/omarchy/chromium/extensions/"*|\
    "$home_dir/.config/chromium/NativeMessagingHosts/"*|\
    "$home_dir/.local/bin/"*) ;;
    *)
      echo "Refusing unmanaged path: $path" >&2
      exit 1
      ;;
  esac
}

assert_safe_home
assert_managed_path "$extension_dir"
assert_managed_path "$native_dir/com.iltumio.cloe.json"
assert_managed_path "$home_dir/.local/bin/cloe-host"

download_dir=$(mktemp -d)
trap 'rm -rf -- "$download_dir"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required to verify CLOE release digests." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required to verify CLOE release digests." >&2; exit 1; }

curl -fsSL -H 'Accept: application/vnd.github+json' "$api_url" \
  -o "$download_dir/release.json"

asset_digest() {
  local asset=$1 digest
  digest=$(jq -r --arg asset "$asset" \
    '.assets[] | select(.name == $asset) | .digest // empty' \
    "$download_dir/release.json")
  [[ "$digest" == sha256:* ]] || {
    echo "No SHA-256 digest published for CLOE asset: $asset" >&2
    exit 1
  }
  printf '%s\n' "${digest#sha256:}"
}

download_verified() {
  local asset=$1 destination=$2 expected actual
  expected=$(asset_digest "$asset")
  curl -fsSL "$base_url/$asset" -o "$destination"
  actual=$(sha256sum "$destination" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || {
    echo "CLOE checksum mismatch for $asset" >&2
    exit 1
  }
}

case "$(uname -m)" in
  x86_64|amd64) host_asset="cloe-host-linux-x86_64" ;;
  aarch64|arm64) host_asset="cloe-host-linux-aarch64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

download_verified "cloe-extension.zip" "$download_dir/cloe-extension.zip"
download_verified "$host_asset" "$download_dir/$host_asset"

mkdir -p "$extension_dir" "$native_dir" "$(dirname -- "$flags_file")"
unzip -oq "$download_dir/cloe-extension.zip" -d "$extension_dir"
install -Dm755 "$download_dir/$host_asset" "$home_dir/.local/bin/cloe-host"
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

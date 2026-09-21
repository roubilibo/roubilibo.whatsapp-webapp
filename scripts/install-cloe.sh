#!/usr/bin/env bash
set -euo pipefail

home_dir=${HOME:?HOME is required}
version=${CLOE_VERSION:-v0.1.0}
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

case "$version" in
  v0.1.0)
    # These digests are repository-controlled pins for the reviewed release.
    base_url="https://github.com/iltumio/cloe/releases/download/$version"
    extension_sha256=7a0fd8f372bc46feb69a14f7a24246b620517e0ef7cff91444fea7cbb8a49143
    case "$(uname -m)" in
      x86_64|amd64)
        host_asset=cloe-host-linux-x86_64
        host_sha256=3ced48991fad67986f5aab2581802af0b546b60785d8b26b479129197da546e9
        ;;
      aarch64|arm64)
        host_asset=cloe-host-linux-aarch64
        host_sha256=fb5c4f656bf3ee9111345223f63f63ac0f7d7f9f378cc310327bf78ebef6eff5
        ;;
      *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported CLOE version: $version (supported: v0.1.0)" >&2
    exit 1
    ;;
esac

download_dir=$(mktemp -d)
trap 'rm -rf -- "$download_dir"' EXIT

download_verified() {
  local asset=$1 destination=$2 expected=$3 actual
  curl -fsSL "$base_url/$asset" -o "$destination"
  actual=$(sha256sum "$destination" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || {
    echo "CLOE checksum mismatch for $asset" >&2
    exit 1
  }
}

download_verified "cloe-extension.zip" "$download_dir/cloe-extension.zip" "$extension_sha256"
download_verified "$host_asset" "$download_dir/$host_asset" "$host_sha256"

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

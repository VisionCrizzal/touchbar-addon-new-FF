#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_DIR="$REPO_ROOT/touchbar-browser-helper"

INSTALL_DIR="$HOME/Library/Application Support/touchbar-browser-helper"
INSTALL_BIN="$INSTALL_DIR/touchbar-browser-helper"
HOST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
HOST_MANIFEST="$HOST_DIR/touchbar_browser_helper.json"
GECKO_ID="touchbar-addon-new-ff@visioncrizzal.github.com"

echo "Building touchbar-browser-helper (release)..."
cd "$HELPER_DIR"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BUILT_BIN="$BIN_DIR/touchbar-browser-helper"
if [[ ! -x "$BUILT_BIN" ]]; then
  echo "Error: Built binary not found at $BUILT_BIN" >&2
  exit 1
fi

echo "Installing binary to $INSTALL_BIN..."
mkdir -p "$INSTALL_DIR"
cp "$BUILT_BIN" "$INSTALL_BIN"
chmod 755 "$INSTALL_BIN"
codesign --force --sign - "$INSTALL_BIN"

echo "Writing Native Messaging host manifest to $HOST_MANIFEST..."
mkdir -p "$HOST_DIR"
python3 - "$HOST_MANIFEST" "$INSTALL_BIN" "$GECKO_ID" <<'PY'
import json, sys

manifest_path, bin_path, gecko_id = sys.argv[1:4]
manifest = {
    "name": "touchbar_browser_helper",
    "description": "native touchbar integration helper",
    "path": bin_path,
    "type": "stdio",
    "allowed_extensions": [gecko_id],
}
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
PY

python3 -m json.tool "$HOST_MANIFEST" >/dev/null
codesign -dv "$INSTALL_BIN"

echo "Native Messaging Host installed successfully."

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_DIR="$REPO_ROOT/touchbar-browser-helper"
DIST_DIR="$REPO_ROOT/dist"
ARCH="$(uname -m)"
PKG_NAME="touchbar-browser-helper-macos-${ARCH}"
STAGE_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

echo "Building touchbar-browser-helper (release, ${ARCH})..."
cd "$HELPER_DIR"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BUILT_BIN="$BIN_DIR/touchbar-browser-helper"
if [[ ! -x "$BUILT_BIN" ]]; then
  echo "Error: Built binary not found at $BUILT_BIN" >&2
  exit 1
fi

BUNDLE_DIR="$STAGE_DIR/$PKG_NAME"
mkdir -p "$BUNDLE_DIR"
cp "$BUILT_BIN" "$BUNDLE_DIR/touchbar-browser-helper"
chmod 755 "$BUNDLE_DIR/touchbar-browser-helper"
codesign --force --sign - "$BUNDLE_DIR/touchbar-browser-helper"

cat >"$BUNDLE_DIR/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_BIN="$SCRIPT_DIR/touchbar-browser-helper"
INSTALL_DIR="$HOME/Library/Application Support/touchbar-browser-helper"
INSTALL_BIN="$INSTALL_DIR/touchbar-browser-helper"
HOST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
HOST_MANIFEST="$HOST_DIR/touchbar_browser_helper.json"
GECKO_ID="touchbar-addon-new-ff@visioncrizzal.github.com"

if [[ ! -f "$SRC_BIN" ]]; then
  echo "Error: touchbar-browser-helper binary missing next to install.sh" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$HOST_DIR"
cp "$SRC_BIN" "$INSTALL_BIN"
chmod 755 "$INSTALL_BIN"
xattr -d com.apple.quarantine "$INSTALL_BIN" >/dev/null 2>&1 || true
codesign --force --sign - "$INSTALL_BIN" >/dev/null 2>&1 || true

ESCAPED_BIN="${INSTALL_BIN//\\/\\\\}"
ESCAPED_BIN="${ESCAPED_BIN//\"/\\\"}"

cat >"$HOST_MANIFEST" <<JSON
{
  "name": "touchbar_browser_helper",
  "description": "native touchbar integration helper",
  "path": "$ESCAPED_BIN",
  "type": "stdio",
  "allowed_extensions": [
    "$GECKO_ID"
  ]
}
JSON

echo "Installed touchbar-browser-helper to: $INSTALL_BIN"
echo "Wrote Native Messaging manifest to: $HOST_MANIFEST"
echo "Restart Firefox (if running) and open the Touchbar Addon popup to confirm 'Helper Connected'."
EOF
chmod 755 "$BUNDLE_DIR/install.sh"

cat >"$BUNDLE_DIR/uninstall.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

rm -rf "$HOME/Library/Application Support/touchbar-browser-helper"
rm -f "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json"
echo "Removed touchbar-browser-helper and Firefox Native Messaging manifest."
EOF
chmod 755 "$BUNDLE_DIR/uninstall.sh"

cat >"$BUNDLE_DIR/README.txt" <<'EOF'
Touchbar Addon for Firefox - macOS Companion Helper
===================================================

1. Run ./install.sh in Terminal.
2. Restart Firefox if it is already open.
3. Click the Touchbar Addon toolbar icon in Firefox to verify "Helper Connected".

To remove later, run ./uninstall.sh.
Source & license (GPL-3.0): https://github.com/VisionCrizzal/touchbar-addon-new-FF
EOF

mkdir -p "$DIST_DIR"
OUT_ARCHIVE="$DIST_DIR/${PKG_NAME}.tar.gz"
rm -f "$OUT_ARCHIVE"
tar -C "$STAGE_DIR" -czf "$OUT_ARCHIVE" "$PKG_NAME"
chmod +x "$SCRIPT_DIR/package-native-host.sh"

echo "Created standalone macOS helper archive: $OUT_ARCHIVE"

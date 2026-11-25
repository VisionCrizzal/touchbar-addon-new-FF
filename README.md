# Touchbar Addon for Firefox (`touchbar-addon-new-FF`)

Native macOS Touch Bar controls for **Mozilla Firefox**.

Forked from [`viktorstrate/native-touchbar-addon`](https://github.com/viktorstrate/native-touchbar-addon) under **GPL-3.0**.

---

## Features

- **Seamless Native Touch Bar Replacement**: Replaces Firefox's default Touch Bar cleanly without an extra `(×)` close box or Control Strip globe icon (with optional Full-width mode in Settings).
- **Microsoft Edge-Style Tab Scrubber**: Compact navigation (`< | >` segmented history + `↻` reload), real tab favicons rendered in `NSScrubber`, smart compact tiles when `>= 5` tabs are open, audio/mute/pin badges, and `+` New Tab.
- **Media ↔ Tabs Switch Button**: 1-tap toggle between active/background playing media (YouTube, HTML5 media) and the Open Tabs scrubber without losing playback progress.
- **Smart Auto-Show & Auto-Dismiss**: Automatically shows the Touch Bar when Firefox is active with an open window, and automatically hides it when switching apps, hiding (`Cmd+H`), or closing all Firefox windows (`×` / `Cmd+W`) without `Cmd+Q`.
- **YouTube & Generic HTML5 Media**: Compact Play/Pause, `-10s` / `+10s` seek buttons, and progress scrubber on YouTube (`/watch` and `/shorts/`) plus automatic HTML5 `<video>` / `<audio>` detection on other sites.
- **Customizable Popup Settings**: Click the Touch Bar toolbar icon in Firefox to verify **Helper Connected** status and customize controls.

---

## Installation (macOS)

> **Requirements:** A Mac with hardware Touch Bar support running macOS 13+ (tested on macOS 15.7.4 `x86_64`) and **Mozilla Firefox 142+**.

Because Firefox WebExtensions cannot draw directly to Apple's Touch Bar hardware, installation requires **both** the Firefox extension and the local companion helper (`touchbar-browser-helper`).

### 1. Install the macOS Companion Helper

#### Option A — Prebuilt Binary (Intel `x86_64` Touch Bar Macs, no Xcode/Node needed)

1. Download `touchbar-browser-helper-macos-x86_64.tar.gz` from the [**Latest GitHub Release**](https://github.com/VisionCrizzal/touchbar-addon-new-FF/releases/latest).
2. Extract and run the installer in Terminal:
   ```sh
   tar -xzf touchbar-browser-helper-macos-x86_64.tar.gz
   cd touchbar-browser-helper-macos-x86_64
   ./install.sh
   ```
   *(Installs the binary into `~/Library/Application Support/touchbar-browser-helper/` and registers `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`.)*

#### Option B — Build Locally from Source (Intel `x86_64` or Apple Silicon M1/M2 Touch Bar Macs)

Requires **Xcode Command Line Tools** (`xcode-select --install`) — full `Xcode.app` is **not** required:

```sh
git clone https://github.com/VisionCrizzal/touchbar-addon-new-FF.git
cd touchbar-addon-new-FF
./scripts/install-native-host.sh
```

### 2. Install the Firefox Extension

- **Mozilla Add-ons (AMO):** Install from Firefox Add-ons once public review is approved *(currently `v0.2.1` Awaiting Review — see [`AMO_SUBMISSION.md`](./AMO_SUBMISSION.md))*.
- **Or load a local development build** (see [Building from Source](#building-from-source) below).

After installing both parts, **quit Firefox completely (`Cmd+Q`) once and reopen it**, then click the Touch Bar icon in the Firefox toolbar to confirm status reads **`Helper Connected`**.

### Uninstall Companion Helper

Run `./uninstall.sh` from the extracted release archive, or remove the installed helper files:

```sh
rm -rf "$HOME/Library/Application Support/touchbar-browser-helper" \
  "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json"
```

---

## How It Works & Privacy

1. **Native Helper (`touchbar-browser-helper/`)**: A SwiftPM CLI executable (`AppKit` + `DFRFoundation`) launched on demand by Firefox over stdio [Native Messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).
2. **Firefox Extension (`browser-addon/`)**: A Manifest V2 WebExtension (zero runtime npm dependencies, unminified `esbuild` output for review transparency) using declarative `content_scripts`, `browser.contentScripts.register()`, and a plain-DOM settings popup.

Zero analytics, zero telemetry, zero remote network calls — see [`PRIVACY.md`](./PRIVACY.md).

---

## Building from Source

### Build Prerequisites

- **Xcode Command Line Tools** (`xcode-select --install`, tested with Swift 6.2.4 / clang 17) — `Xcode.app` is **not** needed
- **Node.js** & **npm** (tested with Node `v24.14.0` / npm `11.11.1`)

### 1. Build, Install & Test the Native Helper

```sh
# Build release binary, ad-hoc codesign, and register Firefox Native Messaging host
./scripts/install-native-host.sh

# Verify stdio framing, layouts, error handling, and clean EOF exit (7/7 assertions)
node ./scripts/test-native-host.mjs
```

To package a standalone macOS distribution tarball (`dist/touchbar-browser-helper-macos-<arch>.tar.gz` with `install.sh` and `uninstall.sh`):

```sh
./scripts/package-native-host.sh
```

### 2. Build, Lint & Load the Firefox Extension

```sh
cd browser-addon
npm ci
npm run build
npm run lint
```

Compiled extension files are written to `browser-addon/dist/`.

- **Watch mode** during development: `npm run dev`
- **Temporary load in Firefox**:
  1. Open `about:debugging#/runtime/this-firefox`.
  2. Click **Load Temporary Add-on…** and select `browser-addon/dist/manifest.json`.
  3. Click **Inspect** → **Console** to confirm: `Native helper ping response: { type: "ping", success: true, value: "pong" }`.

### 3. Packaging `.zip` & AMO Signing (Maintainers)

```sh
cd browser-addon
npm run package         # -> web-ext-artifacts/touchbar_addon_for_firefox-0.2.1.zip
npm run package:source  # -> web-ext-artifacts/touchbar_addon_for_firefox-0.2.1-source.zip
```

For AMO Unlisted/Listed signing CLI commands (`npm run sign:unlisted`, `npm run sign:listed`) and reviewer notes, see [`AMO_SUBMISSION.md`](./AMO_SUBMISSION.md).

> Note: The Gecko add-on ID in [`browser-addon/static/manifest.json`](./browser-addon/static/manifest.json) (`touchbar-addon-new-ff@visioncrizzal.github.com`) must match `allowed_extensions` in `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`.

---

## Known Issues & Future Fixes

The following legacy site-packet issues from the upstream 2020 fork are tracked for upcoming releases (`v0.2.2+`):

- **GitHub packet controls unresponsive ([`github.touchbar-packet`](./browser-addon/src/touchbar-packets/github.touchbar-packet))**: The GitHub Touch Bar action buttons (`Home`, `Pull requests`, `Issues`, `Marketplace`, `Explore`, and repository nav shortcuts) currently fail to navigate / work properly, rely on legacy GitHub selectors, and do not track GitHub's Turbo SPA navigation. Needs a full rewrite or option to disable site shortcuts in favor of the Global Firefox Bar.
- **YouTube `Trending` button obsolete ([`youtube.touchbar-packet`](./browser-addon/src/touchbar-packets/youtube.touchbar-packet))**: `setupGeneralNavigation()` on YouTube non-watch pages still shows a `Trending` button (`/feed/trending` / sidebar guide item), even though YouTube has removed the Trending feed. Needs removal or replacement with an active YouTube navigation action.

---

## License

GNU General Public License v3.0 — see [`LICENSE`](./LICENSE).

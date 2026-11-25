# Touchbar Addon for Firefox (`touchbar-addon-new-FF`)

Native macOS Touch Bar controls for **Mozilla Firefox**.

Forked from [`viktorstrate/native-touchbar-addon`](https://github.com/viktorstrate/native-touchbar-addon) under **GPL-3.0**.

---

## Features

- **Seamless Native Touch Bar Replacement**: Replaces Firefox's default Touch Bar cleanly without an extra `(×)` close box or Control Strip globe icon (with optional Full-width mode in Settings).
- **Microsoft Edge-Style Tab Scrubber**: Compact navigation (`< | >` segmented history + `↻` reload), real tab favicons rendered in `NSScrubber`, smart compact tiles when `>= 5` tabs are open, audio/mute/pin badges, and `+` New Tab.
- **Media ↔ Tabs Switch Button**: 1-tap toggle between active/background playing media (YouTube, HTML5 media) and the Open Tabs scrubber without losing playback progress.
- **Auto-Show on Firefox Focus**: Automatically presents the Touch Bar whenever Firefox becomes the frontmost application.
- **YouTube & Generic HTML5 Media**: Compact Play/Pause, `-10s` / `+10s` seek buttons, and wide progress scrubber on YouTube (`/watch` and `/shorts/`) plus automatic HTML5 `<video>` / `<audio>` detection on other sites.
- **Customizable Popup Settings**: Click the Touch Bar add-on icon in Firefox to check Native Helper status and toggle Replace Native Bar, Full-width mode, Navigation, Open Tabs Scrubber, New/Close/Reopen Tab, Mute Tab, Merge Nav, Auto-show, and HTML5 Media.

---

## How it works

1. **Native Helper (`touchbar-browser-helper/`)**: A macOS SwiftPM CLI executable (`AppKit` + `DFRFoundation`) that connects to Firefox over stdio [Native Messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging) and renders `button` (SF Symbols & `bezelColor`), `slider`, `label`, `spacer`, `scrubber` (`NSScrubber`), and `popover` items on the Touch Bar.
2. **Firefox Extension (`browser-addon/`)**: A Manifest V2 WebExtension bundled with `esbuild` that manages global Firefox tab/navigation controls, injects `touchbar` APIs into `touchbar-packets` (`userScripts`), and relays updates to the native helper.

---

## Prerequisites

- macOS with Touch Bar hardware (tested on macOS 15.7.4 `x86_64`)
- **Xcode Command Line Tools** (`xcode-select --install`) — full Xcode.app is **not** required
- **Node.js** & **npm**

---

## 1. Build & Install the Native Messaging Host

Build the Swift helper in release mode, install the binary to `~/Library/Application Support/touchbar-browser-helper/touchbar-browser-helper`, ad-hoc sign it, and write the Firefox Native Messaging manifest to `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`:

```sh
./scripts/install-native-host.sh
```

Verify Native Messaging framing, Phase 2 components, error handling, and clean `stdin` EOF exit:

```sh
node ./scripts/test-native-host.mjs
```

---

## 2. Build the Firefox Extension

```sh
cd browser-addon
npm install
npm run build
npm run lint
```

Built files are written to `browser-addon/dist/`.

For active development with auto-rebuild on file edits:

```sh
cd browser-addon
npm run dev
```

---

## 3. Load in Firefox (Development)

1. Open Firefox and navigate to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…**.
3. Select `browser-addon/dist/manifest.json`.
4. Click **Inspect** and open the **Console** tab to confirm:
   `Native helper ping response: { type: "ping", success: true, value: "pong" }`

---

## 4. Packaging `.xpi` & Permanent Signing (AMO Unlisted)

To create an extension archive in `browser-addon/web-ext-artifacts/`:

```sh
cd browser-addon
npm run package
```

Standard release builds of Firefox require add-ons to be signed by Mozilla before permanent installation:

- **Self-distribution (Unlisted)**: Sign the package as an Unlisted add-on on [Mozilla Add-ons (AMO)](https://addons.mozilla.org/developers/) or via `web-ext sign --channel=unlisted --api-key=... --api-secret=...` using your AMO JWT credentials, then install the resulting signed `.xpi` directly in Firefox (`Add-ons and Themes` → gear icon → **Install Add-on From File…**).
- Note that the Gecko add-on ID in `browser-addon/static/manifest.json` (`touchbar-addon-new-ff@visioncrizzal.github.com`) must match `allowed_extensions` in `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`.

---

## License

GNU General Public License v3.0 — see [LICENSE](./LICENSE).

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
2. **Firefox Extension (`browser-addon/`)**: A Manifest V2 WebExtension bundled (unminified for review transparency) with `esbuild` that manages global Firefox tab/navigation controls, registers static content scripts (`contentTouchbarBridge.js` + `packets/*.js`), and relays updates to the native helper.

---

## Privacy

Zero telemetry or remote network calls — see [PRIVACY.md](./PRIVACY.md).

---

## Prerequisites

- macOS with Touch Bar hardware (tested on macOS 15.7.4 `x86_64`)
- **Xcode Command Line Tools** (`xcode-select --install`) if building from source — full Xcode.app is **not** required
- **Node.js** & **npm** (for building the Firefox extension)

---

## 1. Build & Install the Native Messaging Host

Build the Swift helper in release mode, install the binary to `~/Library/Application Support/touchbar-browser-helper/touchbar-browser-helper`, ad-hoc sign it, and write the Firefox Native Messaging manifest to `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`:

```sh
./scripts/install-native-host.sh
```

To package a standalone prebuilt macOS `.tar.gz` archive (including `install.sh` and `uninstall.sh` for GitHub Releases):

```sh
./scripts/package-native-host.sh
# Outputs: dist/touchbar-browser-helper-macos-<arch>.tar.gz
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

## 4. Packaging `.xpi` & AMO Signing (Unlisted & Listed)

Standard release builds of Firefox require add-ons to be signed by Mozilla before permanent installation. See [`AMO_SUBMISSION.md`](./AMO_SUBMISSION.md) for the complete public **AMO Listed** store submission checklist, listing text, and Reviewer Notes.

### Step 1 — Build extension & source archives

```sh
cd browser-addon
npm run package
npm run package:source
```

This outputs both `web-ext-artifacts/touchbar_addon_for_firefox-0.2.1.zip` and a clean source archive `web-ext-artifacts/touchbar_addon_for_firefox-0.2.1-source.zip`.

### Step 2 — Get Mozilla Add-ons (AMO) API credentials

1. Sign in at [Mozilla Add-ons Developer Hub](https://addons.mozilla.org/developers/) and accept the Developer Agreement.
2. Generate JWT credentials (**JWT issuer** & **JWT secret**) at [`https://addons.mozilla.org/developers/addon/api/key/`](https://addons.mozilla.org/developers/addon/api/key/).

### Step 3 — Sign via CLI (`sign:unlisted` or `sign:listed`)

Pass your AMO credentials via inline environment variables:

```sh
cd browser-addon
WEB_EXT_API_KEY="user:12345678:901" WEB_EXT_API_SECRET="your-secret" npm run sign:unlisted
```

Or store them locally in `browser-addon/.env.amo` (ignored by `.gitignore`) and run `npm run sign:unlisted` (or `npm run sign:listed` for public AMO Listed submission with [`amo-metadata.json`](./browser-addon/amo-metadata.json)):

```env
WEB_EXT_API_KEY=user:12345678:901
WEB_EXT_API_SECRET=your-secret
```

Both scripts run `npm run build`, `web-ext lint`, create `*-source.zip`, and execute `web-ext sign` cleanly (`--dry-run` supported).

> **Manual web upload alternative**: On [AMO Developer Hub](https://addons.mozilla.org/developers/), submit `touchbar_addon_for_firefox-0.2.1.zip` + `touchbar_addon_for_firefox-0.2.1-source.zip` with build command `npm ci && npm run build` (see [`AMO_SUBMISSION.md`](./AMO_SUBMISSION.md) for copy-paste metadata and Reviewer Notes).

### Step 4 — Install permanently in Firefox

1. Remove the temporary extension in `about:debugging#/runtime/this-firefox` (or restart Firefox).
2. Open `about:addons` → gear icon → **Install Add-on From File…**.
3. Select the signed `.xpi` inside `browser-addon/web-ext-artifacts/`.
4. Open the Touch Bar add-on popup to confirm **Native Helper** reports `Connected`.

> **Compatibility notes**:
> - The Gecko add-on ID in `browser-addon/static/manifest.json` (`touchbar-addon-new-ff@visioncrizzal.github.com`) matches `allowed_extensions` in `~/Library/Application Support/Mozilla/NativeMessagingHosts/touchbar_browser_helper.json`.
> - No custom `update_url` is set in `manifest.json`, keeping this ID ready to transition to the public AMO **Listed** store in a future version bump.

---

## License

GNU General Public License v3.0 — see [LICENSE](./LICENSE).

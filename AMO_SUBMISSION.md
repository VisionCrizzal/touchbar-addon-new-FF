# Mozilla Add-ons (AMO) Listed Submission Guide

This document contains everything required to submit **`Touchbar Addon for Firefox`** (`v0.2.1`) to the official **Mozilla Add-ons (`addons.mozilla.org`) Listed store**.

---

## 1. Pre-flight Compliance Checklist (Already Completed in Repo)

- [x] **Unique Gecko ID**: `touchbar-addon-new-ff@visioncrizzal.github.com` (matches `touchbar_browser_helper.json`)
- [x] **No custom `update_url`**: allows smooth transition from `v0.2.0` (Unlisted) → `v0.2.1` (Listed)
- [x] **`data_collection_permissions`**: `"required": ["none"]` configured in [`browser-addon/static/manifest.json`](./browser-addon/static/manifest.json)
- [x] **No `user_scripts` API / No dynamic `code:` strings**: all 4 built-in site packets are static `content_scripts` entries in `manifest.json`; toggleable HTML5 Media uses `browser.contentScripts.register()` with static `/packets/generic-media.js`; page stop uses `/stopPage.js`
- [x] **Zero runtime UI dependencies & zero lint warnings**: popup uses vanilla DOM helpers (`textContent` / `createElement` only — no `innerHTML`) and outputs unminified JS (`minify: false`)
- [x] **PNG Icons**: `48×48`, `96×96`, and `128×128` PNG icons in `browser-addon/static/icons/`
- [x] **Privacy Policy**: [`PRIVACY.md`](./PRIVACY.md) in repository root

---

## 2. Build Artifacts Before Submitting

### Extension `.zip` + Clean Source `.zip`

```sh
cd browser-addon
npm ci
npm run lint
npm run package
npm run package:source
```

Generated artifacts:
- Extension archive: `browser-addon/web-ext-artifacts/touchbar_addon_for_firefox-0.2.1.zip`
- Reproducible source archive: `browser-addon/web-ext-artifacts/touchbar_addon_for_firefox-0.2.1-source.zip`

### Prebuilt macOS Helper Release Archive (Recommended for End Users on AMO)

Because AMO `.xpi` packages cannot bundle native macOS binaries, build the standalone helper tarball and attach it to a **GitHub Release** (`v0.2.1`) on `VisionCrizzal/touchbar-addon-new-FF`:

```sh
./scripts/package-native-host.sh
# Outputs: dist/touchbar-browser-helper-macos-<arch>.tar.gz (with install.sh & uninstall.sh)
```

---

## 3. Submit via CLI (`npm run sign:listed`) OR Web Developer Hub

### Option A — CLI (`web-ext sign --channel=listed`)

Ensure `browser-addon/.env.amo` (or `WEB_EXT_API_KEY` / `WEB_EXT_API_SECRET`) is configured, preview first with `--dry-run`, then run:

```sh
cd browser-addon
node scripts/sign-listed.mjs --dry-run
npm run sign:listed
```

This uploads `dist/`, [`browser-addon/amo-metadata.json`](./browser-addon/amo-metadata.json), and `touchbar_addon_for_firefox-0.2.1-source.zip`.  
*(Note: If you already converted or edited the listing metadata on the AMO website and only want to upload a new version, pass `--skip-metadata`.)*

### Option B — AMO Web Developer Hub (`https://addons.mozilla.org/developers/addon/submit/`)

If transitioning from `v0.2.0` Unlisted on the web dashboard, open **My Add-ons** → **Touchbar Addon for Firefox** → **Submit a New Version** (and change visibility / channel to **On this site** / Listed), then copy-paste the fields below:

---

## 4. Copy-Paste Store Listing Fields

### Summary (max 250 chars)
```text
Native macOS Touch Bar controls for Firefox: compact navigation, Edge-style open tab scrubber with favicons, and YouTube/HTML5 media controls.
```

### Categories
- **Tabs** (`tabs`)
- **Appearance** (`appearance`)

### License
- **GNU General Public License v3.0** (`GPL-3.0-only`)

### Homepage & Support
- **Homepage URL:** `https://github.com/VisionCrizzal/touchbar-addon-new-FF`
- **Support Site URL:** `https://github.com/VisionCrizzal/touchbar-addon-new-FF/issues`
- **Privacy Policy URL:** `https://github.com/VisionCrizzal/touchbar-addon-new-FF/blob/master/PRIVACY.md`

### Description
```text
IMPORTANT: macOS with Touch Bar hardware + Companion Helper required

Firefox WebExtensions cannot access Apple's Touch Bar hardware APIs directly, so this extension pairs with the open-source local helper binary (`touchbar-browser-helper`, GPL-3.0). Before using the Touch Bar controls, install the companion helper from:
https://github.com/VisionCrizzal/touchbar-addon-new-FF

Features:
- Microsoft Edge-style compact Touch Bar layout with optional native Touch Bar replacement and Full-width mode
- Scrollable Open Tabs Switcher displaying live favicons, audio/mute indicators, and pinned badges
- Navigation & Tab Management: compact Back / Forward segmented control, Reload / Stop, New Tab (+), Close Tab, Reopen Closed Tab, and Mute Tab
- YouTube & Generic HTML5 Media controls: compact Play/Pause, -10s / +10s seek, and progress scrubber
- 1-tap Media <-> Tabs switch button when playing audio/video in the active or a background tab
- Auto-show Touch Bar when Firefox becomes the frontmost window
- Toolbar popup UI to check helper connection status and toggle features

Privacy & Security:
All Touch Bar state stays strictly local on your Mac over Firefox stdio Native Messaging. Zero analytics, zero telemetry, zero remote servers.
```

### Screenshots to Upload on AMO
Upload clear screenshots/photos showing:
1. Firefox open tabs scrubber on the macOS Touch Bar (`Global Firefox Bar` / Edge-style clone)
2. YouTube video playback controls & progress scrubber on the Touch Bar
3. Extension toolbar popup showing `Helper Connected` and Settings toggles

---

## 5. Copy-Paste "Notes to Reviewers" (Mandatory for `nativeMessaging` + Host Permissions)

```text
1. Purpose & Hardware Requirement:
This extension integrates Mozilla Firefox with the physical macOS Touch Bar on Touch Bar MacBook Pro models. Because WebExtension APIs cannot draw NSTouchBar items directly, the extension communicates locally over Firefox's standard stdio Native Messaging API (`touchbar_browser_helper`) with an open-source Swift companion CLI (`touchbar-browser-helper`), available in the repository:
https://github.com/VisionCrizzal/touchbar-addon-new-FF

2. Native Messaging Security Boundary:
- All messages exchanged over `browser.runtime.connectNative('touchbar_browser_helper')` are structured JSON UI descriptors (`change_layout`, `update_item`, `dismiss_touchbar`, `set_config`, `ping`) and tap/scrub callback events (`action`).
- The native helper performs zero shell execution, zero eval/AppleScript execution, and zero outbound network requests.
- To test the extension with the helper on macOS: clone the repo and run `./scripts/install-native-host.sh` (requires Xcode Command Line Tools on a Touch Bar Mac, or install the prebuilt archive from GitHub Releases). Without the native helper installed, the extension degrades gracefully and displays a setup link in the toolbar popup ("Helper Disconnected").

3. Justification of Permissions:
- `nativeMessaging`: Send Touch Bar item layouts to `touchbar-browser-helper` and receive button/scrubber tap events.
- `http://*/*`, `https://*/*`: Register the toggleable HTML5 media detector (`browser.contentScripts.register` with static `/packets/generic-media.js`) and rehydrate already-open tabs after install/reload via static file injection (`browser.tabs.executeScript({ file })`). No inline code strings (`code:`) are executed.
- `tabs`: Query tab titles, favicons (rendered locally via 32x32 Canvas to PNG base64 in memory), active/audible/muted/pinned states, and trigger Back/Forward/Reload/New/Close/Mute actions.
- `sessions`: Implement "Reopen Closed Tab" (`sessions.getRecentlyClosed` / `sessions.restore`) and track per-tab host changes (`sessions.getTabValue` / `setTabValue`).
- `storage`: Persist extension preferences locally via `browser.storage.local`.

4. Source Code & Reproducible Build:
Although the submitted bundle uses esbuild to resolve ES module imports, `minify: false` is set in `browser-addon/scripts/build.mjs` so all compiled files (`dist/background.js`, `dist/popup.js`, `dist/contentTouchbarBridge.js`, `dist/packets/*.js`) are unminified and readable. There are zero runtime npm dependencies (React/third-party UI frameworks were removed; popup UI uses plain DOM `createElement`/`textContent` with zero `innerHTML`).

To reproduce the exact `dist/` directory from the uploaded source archive:
- Runtime: Node.js v24.14.0 / npm
- Commands:
    npm ci
    npm run build
```

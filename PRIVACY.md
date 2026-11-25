# Privacy Policy — Touchbar Addon for Firefox

**Effective Date:** November 25, 2026  
**Add-on ID:** `touchbar-addon-new-ff@visioncrizzal.github.com`  
**Repository:** [VisionCrizzal/touchbar-addon-new-FF](https://github.com/VisionCrizzal/touchbar-addon-new-FF)

## Summary

Touchbar Addon for Firefox does **not** collect, store remotely, sell, or transmit any personal data, browsing history, analytics, or telemetry.

## What Data Is Processed Locally

1. **Extension Settings (`storage` permission)**  
   Your Touch Bar preferences (for example: whether to show open tabs, navigation buttons, auto-show behavior, or HTML5 media controls) are saved locally in Firefox via `browser.storage.local`. This data never leaves your browser.

2. **Tab State & Native Messaging (`tabs`, `sessions`, `nativeMessaging` permissions)**  
   To display open Firefox tabs, favicons, audio/mute indicators, and active media controls on the physical macOS Touch Bar, the extension sends layout metadata and button-action events strictly over local standard input/output (`stdio`) Native Messaging to the open-source companion binary (`touchbar-browser-helper`) installed by you on your own Mac.
   - No tab titles, URLs, favicons, or playback states are persisted to disk by the helper or transmitted over any network connection.

3. **Content Scripts (`http://*/*`, `https://*/*` permissions)**  
   Built-in content scripts run locally in your browser tabs solely to detect HTML5 `<video>` / `<audio>` players and provide Touch Bar media playback/seek controls on YouTube and other media sites, plus quick-navigation buttons on supported sites (GitHub, Google, Facebook). No page content is sent outside your device.

## Third-Party Services & Analytics

None. This extension includes zero external analytics, zero tracking SDKs, zero ads, and makes no outbound network requests to any developer-controlled server.

## Contact

If you have questions about this privacy policy, please open an issue at:  
[https://github.com/VisionCrizzal/touchbar-addon-new-FF/issues](https://github.com/VisionCrizzal/touchbar-addon-new-FF/issues)

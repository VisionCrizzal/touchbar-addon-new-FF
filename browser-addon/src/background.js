/**
 * Entry point for background script
 * Configures and loads everything
 */

import { loadNativePort } from './nativeBridge'
import { loadTabManagement } from './tabManagement'
import { loadTouchbarPackets, rehydrateOpenTabs } from './touchbarPackets'
import { loadPopupAPI } from './popupApi'
import { loadSettings } from './settings'

async function init() {
  const nativePort = browser.runtime.connectNative('touchbar_browser_helper')
  const settings = await loadSettings()

  console.log('background start')

  loadTabManagement({ nativePort, settings })
  loadNativePort({ nativePort, settings })
  loadPopupAPI()

  await loadTouchbarPackets({
    enableGenericMedia: settings.enableGenericMedia,
  })
  await rehydrateOpenTabs({
    enableGenericMedia: settings.enableGenericMedia,
  })
}

init().catch(err => {
  console.error('Background initialization error:', err)
})

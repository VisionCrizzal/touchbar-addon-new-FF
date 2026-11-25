/**
 * Entry point for background script
 * Configures and loads everything
 */

import { loadNativePort } from './nativeBridge'
import { loadTabManagement } from './tabManagement'
import { loadTouchbarPackets } from './touchbarPackets'
import { loadPopupAPI } from './popupApi'
import { loadSettings } from './settings'

async function init() {
  const nativePort = browser.runtime.connectNative('touchbar_browser_helper')
  const settings = await loadSettings()

  console.log('background start')

  await loadTouchbarPackets({
    enableGenericMedia: settings.enableGenericMedia,
  })
  loadTabManagement({ nativePort, settings })
  loadNativePort({ nativePort, settings })
  loadPopupAPI()
}

init().catch(err => {
  console.error('Background initialization error:', err)
})

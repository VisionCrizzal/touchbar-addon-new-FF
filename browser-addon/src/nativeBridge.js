/**
 * Load native binary and communication to and from it
 */

import { handleGlobalAction } from './globalTouchbar'
import * as tabManagement from './tabManagement'

let nativeConnected = false

export const isNativeConnected = () => nativeConnected

export const loadNativePort = ({ nativePort, settings }) => {
  nativePort.onDisconnect.addListener(p => {
    nativeConnected = false
    const reason =
      p?.error?.message || browser.runtime.lastError?.message || 'unknown reason'
    console.log(`Disconnected from native helper: ${reason}`)
  })

  browser.runtime.onMessage.addListener((message, sender) => {
    if (message.scope != 'native_bridge') return
    if (!sender.tab) return

    if (message.type == 'send_native_message') {
      if (message.nativeMessage.type == 'change_layout') {
        tabManagement.setTabTouchbarLayout(
          sender.tab.id,
          message.nativeMessage.layout,
          false
        )

        browser.tabs
          .query({ active: true, currentWindow: true })
          .then(tabs => {
            if (
              tabs?.[0]?.id === sender.tab.id ||
              tabManagement.getControlTargetTabId() === sender.tab.id
            ) {
              tabManagement.refreshTouchbarForActiveTab()
            }
          })
        return
      }

      if (message.nativeMessage.type == 'update_item') {
        tabManagement.updateTabTouchbarLayout(
          sender.tab.id,
          message.nativeMessage.name,
          message.nativeMessage.values
        )

        if (tabManagement.getControlTargetTabId() === sender.tab.id) {
          nativePort.postMessage(message.nativeMessage)
        }
      }
    }
  })

  nativePort.onMessage.addListener(response => {
    if (response && response.type === 'ping') {
      nativeConnected = true
      console.log('Native helper ping response:', response)
      return
    }

    if (response?.name === '__global_toggle_mode') {
      tabManagement.toggleMediaTabsMode()
      return
    }

    if (response?.name?.startsWith('__global_')) {
      handleGlobalAction(response)
      return
    }

    const targetTabId = tabManagement.getControlTargetTabId()

    if (targetTabId) {
      browser.tabs
        .sendMessage(targetTabId, {
          ...response,
          scope: 'native_bridge_response',
        })
        .catch(() => {})
    }
  })

  nativePort.postMessage({
    type: 'set_config',
    autoPresent: settings?.autoPresent ?? true,
    replaceNative: settings?.replaceNativeTouchBar ?? true,
    fullWidth: settings?.fullWidthMode ?? false,
  })
  nativePort.postMessage({ type: 'ping' })
  tabManagement.refreshTouchbarForActiveTab()
}

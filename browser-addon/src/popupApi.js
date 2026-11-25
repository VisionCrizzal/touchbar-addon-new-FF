import { isNativeConnected } from './nativeBridge'
import { loadSettings, saveSettings } from './settings'
import { getActiveTabStatus, updateSettings as applyTabSettings } from './tabManagement'
import { setGenericMediaEnabled, touchbarPackets } from './touchbarPackets'

/**
 * API for popup to get information from background script
 */

const sendPopupMessage = (type, payload) =>
  browser.runtime.sendMessage({
    scope: 'popup_message',
    type,
    payload,
  })

export const loadPopupAPI = () => {
  browser.runtime.onMessage.addListener(message => {
    if (message.scope != 'popup_message') return

    switch (message.type) {
      case 'get_touchbar_packets':
        return Promise.resolve(touchbarPackets)
      case 'get_settings':
        return loadSettings()
      case 'update_settings':
        return (async () => {
          const updated = await saveSettings(message.payload || {})
          await setGenericMediaEnabled(updated.enableGenericMedia)
          await applyTabSettings(updated)
          return updated
        })()
      case 'get_status':
        return Promise.resolve({
          nativeConnected: isNativeConnected(),
          activeStatus: getActiveTabStatus(),
        })
    }
  })
}

export const activePacketChanged = newActivePacket => {
  sendPopupMessage('active_packet_changed', newActivePacket)
}

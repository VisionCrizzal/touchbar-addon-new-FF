/**
 * API to get information from background script
 */

const sendPopupMessage = (type, payload) =>
  browser.runtime.sendMessage({
    scope: 'popup_message',
    type,
    payload,
  })

const listenerMap = new WeakMap()

export const addPopupMessageListener = listener => {
  const wrapped = (message, sender, sendResponse) => {
    if (message.scope === 'popup_message') {
      listener(message, sender, sendResponse)
    }
  }
  listenerMap.set(listener, wrapped)
  browser.runtime.onMessage.addListener(wrapped)
}

export const removePopupMessageListener = listener => {
  const wrapped = listenerMap.get(listener) || listener
  browser.runtime.onMessage.removeListener(wrapped)
  listenerMap.delete(listener)
}

/**
 * Get all installed touchbar-packets
 * @return Promise a promise resolving to a list of touchbar-packets
 */
export const getTouchbarPackets = () => sendPopupMessage('get_touchbar_packets')

export const getSettings = () => sendPopupMessage('get_settings')

export const updateSettings = partial =>
  sendPopupMessage('update_settings', partial)

export const getStatus = () => sendPopupMessage('get_status')

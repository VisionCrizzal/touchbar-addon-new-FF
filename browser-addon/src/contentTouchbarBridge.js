/**
 * Content-script fallback bridge for tabs that were already open before extension load/reload
 */

if (typeof globalThis.touchbar === 'undefined') {
  globalThis.touchbar = {
    changeLayout: layout => {
      browser.runtime.sendMessage({
        scope: 'native_bridge',
        type: 'send_native_message',
        nativeMessage: {
          type: 'change_layout',
          layout,
        },
      })
    },
    updateItem: (name, values) => {
      browser.runtime.sendMessage({
        scope: 'native_bridge',
        type: 'send_native_message',
        nativeMessage: {
          type: 'update_item',
          name,
          values,
        },
      })
    },
    addEventListener: listener => {
      browser.runtime.onMessage.addListener(message => {
        if (message && message.scope === 'native_bridge_response') {
          listener(message)
        }
      })
    },
  }
}

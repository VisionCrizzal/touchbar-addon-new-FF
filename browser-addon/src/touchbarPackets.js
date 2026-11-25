/**
 * Configure and register built-in Touch Bar content script packets
 */

const SITE_PACKETS = [
  {
    id: 'youtube',
    headers: {
      name: 'YouTube',
      match: ['https://www.youtube.com/*'],
    },
    file: '/packets/youtube.js',
  },
  {
    id: 'github',
    headers: {
      name: 'GitHub',
      match: ['https://github.com/*'],
    },
    file: '/packets/github.js',
  },
  {
    id: 'google',
    headers: {
      name: 'Google',
      match: [
        'https://www.google.com/?*',
        'https://www.google.com/webhp?*',
        'https://www.google.com/search?*',
      ],
    },
    file: '/packets/google.js',
  },
  {
    id: 'facebook',
    headers: {
      name: 'Facebook',
      match: ['https://www.facebook.com/*', 'https://facebook.com/*'],
    },
    file: '/packets/facebook.js',
  },
]

const GENERIC_MEDIA_PACKET = {
  id: 'generic-media',
  headers: {
    name: 'HTML5 Media',
    match: ['https://*/*', 'http://*/*'],
  },
  file: '/packets/generic-media.js',
}

export const touchbarPackets = [...SITE_PACKETS, GENERIC_MEDIA_PACKET]

let genericRegistration = null

export async function setGenericMediaEnabled(enabled) {
  if (enabled) {
    if (!genericRegistration) {
      genericRegistration = await browser.contentScripts.register({
        matches: GENERIC_MEDIA_PACKET.headers.match,
        excludeMatches: [
          '*://www.youtube.com/*',
          '*://youtube.com/*',
          '*://*.youtube.com/*',
        ],
        js: [
          { file: '/contentTouchbarBridge.js' },
          { file: GENERIC_MEDIA_PACKET.file },
        ],
        runAt: 'document_idle',
      })
    }
  } else if (genericRegistration) {
    await genericRegistration.unregister()
    genericRegistration = null
  }
}

function getRehydrationPacketFile(tabUrl, enableGenericMedia) {
  const url = new URL(tabUrl)
  const hostname = url.hostname

  if (hostname === 'www.youtube.com') {
    return '/packets/youtube.js'
  }
  if (hostname === 'github.com') {
    return '/packets/github.js'
  }
  if (
    hostname === 'www.google.com' &&
    (url.pathname === '/' ||
      url.pathname === '/webhp' ||
      url.pathname === '/search') &&
    url.search.length > 0
  ) {
    return '/packets/google.js'
  }
  if (hostname === 'www.facebook.com' || hostname === 'facebook.com') {
    return '/packets/facebook.js'
  }
  if (
    enableGenericMedia &&
    hostname !== 'youtube.com' &&
    !hostname.endsWith('.youtube.com')
  ) {
    return '/packets/generic-media.js'
  }
  return null
}

export async function rehydrateOpenTabs({ enableGenericMedia = true } = {}) {
  try {
    const openTabs = await browser.tabs.query({
      url: ['http://*/*', 'https://*/*'],
    })

    for (const tab of openTabs) {
      if (!tab?.id || !tab?.url || tab.discarded) continue

      try {
        const packetFile = getRehydrationPacketFile(tab.url, enableGenericMedia)
        if (!packetFile) continue

        await browser.tabs.executeScript(tab.id, {
          file: '/contentTouchbarBridge.js',
        })
        await browser.tabs.executeScript(tab.id, {
          file: packetFile,
        })
      } catch {
        // Ignore restricted or unloaded tabs
      }
    }
  } catch (err) {
    console.warn('Failed to rehydrate open tabs:', err)
  }
}

export const loadTouchbarPackets = async function ({
  enableGenericMedia = true,
} = {}) {
  await setGenericMediaEnabled(enableGenericMedia)
  console.log('All touchbar packets configured')
}

/**
 * Configure and load touchbar packet scripts
 */

import youtubePacket from './touchbar-packets/youtube.touchbar-packet'
import githubPacket from './touchbar-packets/github.touchbar-packet'
import googlePacket from './touchbar-packets/google.touchbar-packet'
import facebookPacket from './touchbar-packets/facebook.touchbar-packet'
import genericMediaPacket from './touchbar-packets/generic-media.touchbar-packet'

/**
 * Parses the header of a touchbar packet
 * @param {string} packet a raw touchbar-packet string
 */
export function parseTouchbarPacket(packet) {
  const [_, header, body] = packet.match(
    /^[\n\s]*\/\/\s+==TouchbarPacket==([^]+)==\/TouchbarPacket==\n([^]+)/
  )

  const headerFields = header
    .match(/@\w+\s.+/g)
    .map(fieldLine => {
      const [_, key, value] = fieldLine.match(/@(\w+)\s(.+)/)
      return [key, value]
    })
    .reduce((result, field) => {
      if (result[field[0]]) {
        result[field[0]].push(field[1])
      } else {
        result[field[0]] = [field[1]]
      }
      return result
    }, {})

  headerFields.name = headerFields.name[0]

  return {
    headers: headerFields,
    script: body,
  }
}

const sitePackets = [
  youtubePacket,
  githubPacket,
  googlePacket,
  facebookPacket,
].map(parseTouchbarPacket)

const genericPacket = parseTouchbarPacket(genericMediaPacket)

export const touchbarPackets = [...sitePackets, genericPacket]

let genericRegistration = null

export async function setGenericMediaEnabled(enabled) {
  if (enabled) {
    if (!genericRegistration) {
      genericRegistration = await browser.userScripts.register({
        matches: genericPacket.headers.match,
        js: [{ code: genericPacket.script }],
        scriptMetadata: {},
      })
    }
  } else if (genericRegistration) {
    await genericRegistration.unregister()
    genericRegistration = null
  }
}

export async function rehydrateOpenTabs({ enableGenericMedia = true } = {}) {
  try {
    const openTabs = await browser.tabs.query({
      url: ['http://*/*', 'https://*/*'],
    })

    for (const tab of openTabs) {
      if (!tab?.id || !tab?.url || tab.discarded) continue

      try {
        const hostname = new URL(tab.url).hostname
        if (hostname === 'www.youtube.com') {
          await browser.tabs.executeScript(tab.id, {
            file: '/contentTouchbarBridge.js',
          })
          await browser.tabs.executeScript(tab.id, {
            file: '/packets/youtube.js',
          })
        } else if (
          enableGenericMedia &&
          hostname !== 'youtube.com' &&
          !hostname.endsWith('.youtube.com')
        ) {
          await browser.tabs.executeScript(tab.id, {
            file: '/contentTouchbarBridge.js',
          })
          await browser.tabs.executeScript(tab.id, {
            file: '/packets/generic-media.js',
          })
        }
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
  const packetRegisterPromises = sitePackets.map(packet => {
    return browser.userScripts.register({
      matches: packet.headers.match,
      js: [
        {
          code: packet.script,
        },
      ],
      scriptMetadata: {},
    })
  })

  await Promise.all(packetRegisterPromises)
  await setGenericMediaEnabled(enableGenericMedia)

  console.log('All touchbar packets loaded')
}

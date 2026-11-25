/**
 * Keeps the Touch Bar in sync with Firefox tabs, windows, and global controls
 */

import {
  buildScrubberItemsAsync,
  composeTouchbarLayoutAsync,
} from './globalTouchbar'
import { DEFAULT_SETTINGS } from './settings'

let tabTouchbarLayouts = {}
let activeTouchbarTab = null
let controlTargetTabId = null
let lastMediaTabId = null
let preferTabsView = false
let preferMediaTabId = null
let currentSettings = { ...DEFAULT_SETTINGS }
let activeNativePort = null
let scrubberVisible = false
let scrubberRefreshTimer = null
let refreshGeneration = 0

export const setTabTouchbarLayout = (tabId, layout, isActive = false) => {
  tabTouchbarLayouts[tabId] = layout
  if (layout?.length) {
    lastMediaTabId = tabId
  }
  if (isActive) {
    activeTouchbarTab = tabId
  }
}

export const setActiveTouchbarTab = tabId => {
  activeTouchbarTab = tabId
}

export const updateTabTouchbarLayout = (tabId, name, changes) => {
  const layout = tabTouchbarLayouts[tabId]
  if (!layout) return

  const itemIndex = layout.findIndex(x => x.name == name)
  if (itemIndex === -1) return

  Object.assign(layout[itemIndex], changes)
}

export const getActiveTouchbarTab = () => activeTouchbarTab

export const getControlTargetTabId = () => controlTargetTabId

export const getActiveTabStatus = () => {
  const hasSiteLayout = Boolean(controlTargetTabId)

  let activeLayoutType = 'Global Firefox Bar'
  if (hasSiteLayout) {
    activeLayoutType = currentSettings.mergeNavWithPackets
      ? 'Site Packet + Nav'
      : 'Site Packet'
  }

  return {
    tabId: activeTouchbarTab,
    hasSiteLayout,
    activeLayoutType,
  }
}

function findBackgroundMediaTab(activeTabId, windowTabs) {
  const audibleMatch = windowTabs.find(
    t =>
      t.id !== activeTabId &&
      t.audible &&
      tabTouchbarLayouts[t.id]?.length
  )
  if (audibleMatch) return audibleMatch

  if (lastMediaTabId && lastMediaTabId !== activeTabId) {
    const recentMatch = windowTabs.find(
      t => t.id === lastMediaTabId && tabTouchbarLayouts[t.id]?.length
    )
    if (recentMatch) return recentMatch
  }

  return (
    windowTabs.find(
      t => t.id !== activeTabId && tabTouchbarLayouts[t.id]?.length
    ) || null
  )
}

function clearAllTouchbarLayouts() {
  tabTouchbarLayouts = {}
  activeTouchbarTab = null
  controlTargetTabId = null
  lastMediaTabId = null
  preferTabsView = false
  preferMediaTabId = null
  scrubberVisible = false

  if (activeNativePort) {
    activeNativePort.postMessage({
      type: 'change_layout',
      layout: [],
    })
  }
}

export async function refreshTouchbarForActiveTab() {
  if (!activeNativePort) return
  const generation = ++refreshGeneration

  try {
    const [activeTab] = await browser.tabs.query({
      active: true,
      currentWindow: true,
    })

    if (generation !== refreshGeneration) return

    if (!activeTab) {
      const openWindows = await browser.windows
        .getAll({ windowTypes: ['normal', 'popup'] })
        .catch(() => [])
      if (generation !== refreshGeneration) return
      if (openWindows.length === 0) {
        clearAllTouchbarLayouts()
      } else {
        scrubberVisible = false
        controlTargetTabId = null
        activeNativePort.postMessage({ type: 'dismiss_touchbar' })
      }
      return
    }

    activeTouchbarTab = activeTab.id

    const windowTabs = await browser.tabs.query({ windowId: activeTab.windowId })
    if (generation !== refreshGeneration) return

    const activeSiteLayout = tabTouchbarLayouts[activeTab.id] || null
    const bgMediaTab = !activeSiteLayout
      ? findBackgroundMediaTab(activeTab.id, windowTabs)
      : null

    let siteLayout = null
    let modeToggle = null

    if (activeSiteLayout) {
      if (currentSettings.showTabScrubber && preferTabsView) {
        siteLayout = null
        modeToggle = 'to_media'
        controlTargetTabId = null
      } else {
        siteLayout = activeSiteLayout
        modeToggle = currentSettings.showTabScrubber ? 'to_tabs' : null
        controlTargetTabId = activeTab.id
      }
    } else if (bgMediaTab) {
      if (preferMediaTabId === bgMediaTab.id) {
        siteLayout = tabTouchbarLayouts[bgMediaTab.id]
        modeToggle = currentSettings.showTabScrubber ? 'to_tabs' : null
        controlTargetTabId = bgMediaTab.id
      } else {
        siteLayout = null
        modeToggle = 'to_media'
        controlTargetTabId = null
      }
    } else {
      preferMediaTabId = null
      siteLayout = null
      modeToggle = null
      controlTargetTabId = null
    }

    const layout = await composeTouchbarLayoutAsync({
      siteLayout,
      activeTab,
      windowTabs,
      settings: currentSettings,
      modeToggle,
    })

    if (generation !== refreshGeneration) return

    scrubberVisible = layout.some(item => item.type === 'scrubber')

    if (layout.length > 0) {
      activeNativePort.postMessage({
        type: 'change_layout',
        layout,
      })
    } else {
      activeNativePort.postMessage({
        type: 'dismiss_touchbar',
      })
    }
  } catch (err) {
    console.warn('Failed to refresh touchbar for active tab:', err)
  }
}

export async function toggleMediaTabsMode() {
  try {
    const [activeTab] = await browser.tabs.query({
      active: true,
      currentWindow: true,
    })
    if (!activeTab) return

    if (tabTouchbarLayouts[activeTab.id]?.length) {
      preferTabsView = !preferTabsView
    } else {
      const windowTabs = await browser.tabs.query({
        windowId: activeTab.windowId,
      })
      const bgMediaTab = findBackgroundMediaTab(activeTab.id, windowTabs)
      if (bgMediaTab) {
        preferMediaTabId =
          preferMediaTabId === bgMediaTab.id ? null : bgMediaTab.id
      } else {
        preferMediaTabId = null
      }
    }

    await refreshTouchbarForActiveTab()
  } catch (err) {
    console.warn('Failed to toggle media/tabs mode:', err)
  }
}

export function refreshScrubberOnly() {
  if (!activeNativePort || !scrubberVisible || !currentSettings.showTabScrubber) {
    return
  }

  if (scrubberRefreshTimer !== null) {
    clearTimeout(scrubberRefreshTimer)
  }

  scrubberRefreshTimer = setTimeout(async () => {
    scrubberRefreshTimer = null
    if (!activeNativePort || !scrubberVisible || !currentSettings.showTabScrubber) {
      return
    }

    try {
      const [activeTab] = await browser.tabs.query({
        active: true,
        currentWindow: true,
      })
      if (!activeTab || controlTargetTabId !== null) {
        return
      }

      const windowTabs = await browser.tabs.query({ windowId: activeTab.windowId })
      const { items, selectedIndex } = await buildScrubberItemsAsync(windowTabs)

      if (!scrubberVisible || controlTargetTabId !== null) return

      activeNativePort.postMessage({
        type: 'update_item',
        name: '__global_tabs',
        values: {
          items,
          selectedIndex,
        },
      })
    } catch (err) {
      console.warn('Failed to refresh tab scrubber:', err)
    }
  }, 80)
}

export async function updateSettings(newSettings) {
  currentSettings = { ...newSettings }
  if (activeNativePort) {
    activeNativePort.postMessage({
      type: 'set_config',
      autoPresent: currentSettings.autoPresent,
      replaceNative: currentSettings.replaceNativeTouchBar,
      fullWidth: currentSettings.fullWidthMode,
    })
  }
  await refreshTouchbarForActiveTab()
}

export const loadTabManagement = ({ nativePort, settings }) => {
  activeNativePort = nativePort
  if (settings) {
    currentSettings = { ...settings }
  }

  browser.tabs.onRemoved.addListener(tabId => {
    delete tabTouchbarLayouts[tabId]
    if (activeTouchbarTab === tabId) {
      activeTouchbarTab = null
    }
    if (lastMediaTabId === tabId) {
      lastMediaTabId = null
    }
    if (preferMediaTabId === tabId || controlTargetTabId === tabId) {
      preferMediaTabId = null
      refreshTouchbarForActiveTab()
    } else {
      refreshScrubberOnly()
    }
  })

  browser.tabs.onActivated.addListener(() => {
    preferTabsView = false
    preferMediaTabId = null
    refreshTouchbarForActiveTab()
  })

  browser.windows.onRemoved.addListener(async () => {
    const openWindows = await browser.windows
      .getAll({ windowTypes: ['normal', 'popup'] })
      .catch(() => [])
    if (openWindows.length === 0) {
      clearAllTouchbarLayouts()
    } else {
      refreshTouchbarForActiveTab()
    }
  })

  browser.windows.onFocusChanged.addListener(() => {
    refreshTouchbarForActiveTab()
  })

  browser.tabs.onCreated.addListener(() => refreshScrubberOnly())
  browser.tabs.onMoved.addListener(() => refreshScrubberOnly())
  browser.tabs.onAttached.addListener(() => refreshScrubberOnly())
  browser.tabs.onDetached.addListener(() => refreshScrubberOnly())

  // Sync URL host changes, navigation icons, mute badge, audible media state, favicons, and scrubber titles
  browser.tabs.onUpdated.addListener(async (tabId, changes, tab) => {
    if (changes.url) {
      const oldUrl = await browser.sessions.getTabValue(tabId, 'configured_url')

      if (oldUrl) {
        try {
          const oldHost = new URL(oldUrl).host
          const newHost = new URL(changes.url).host

          if (oldHost !== newHost) {
            delete tabTouchbarLayouts[tabId]
            if (lastMediaTabId === tabId) {
              lastMediaTabId = null
            }
            if (controlTargetTabId === tabId) {
              preferMediaTabId = null
            }
            if (
              tab.active ||
              activeTouchbarTab === tabId ||
              controlTargetTabId === tabId
            ) {
              await refreshTouchbarForActiveTab()
            }
          }
        } catch (err) {
          console.warn('Invalid URL comparison on tab update', err)
        }
      }

      browser.sessions.setTabValue(tabId, 'configured_url', changes.url)
    }

    if (changes.status && tab.active && currentSettings.showNavigation) {
      nativePort.postMessage({
        type: 'update_item',
        name: '__global_reload',
        values: {
          symbol: changes.status === 'loading' ? 'xmark' : 'arrow.clockwise',
        },
      })
    }

    if (changes.mutedInfo && tab.active && currentSettings.showMuteTab) {
      const muted = Boolean(tab.mutedInfo?.muted)
      nativePort.postMessage({
        type: 'update_item',
        name: '__global_mute_tab',
        values: {
          symbol: muted ? 'speaker.slash.fill' : 'speaker.wave.2.fill',
          bezelColor: muted ? '#c0392b' : '',
        },
      })
    }

    if (
      changes.audible !== undefined &&
      !tab.active &&
      tabTouchbarLayouts[tabId]?.length
    ) {
      await refreshTouchbarForActiveTab()
      return
    }

    if (
      (changes.title ||
        changes.favIconUrl ||
        changes.audible ||
        changes.mutedInfo ||
        changes.pinned) &&
      scrubberVisible
    ) {
      refreshScrubberOnly()
    }
  })
}

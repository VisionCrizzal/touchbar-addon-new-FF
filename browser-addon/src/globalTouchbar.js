/**
 * Global Firefox Touch Bar layout builders and action dispatcher
 */

import { getFaviconBase64 } from './faviconCache'

function truncateLabel(text, maxLen = 36) {
  const clean = (text || 'New Tab').trim()
  if (clean.length <= maxLen) return clean
  return `${clean.slice(0, maxLen - 1)}…`
}

export function buildNavigationItems(activeTab) {
  const isLoading = activeTab?.status === 'loading'
  return [
    {
      type: 'segmented',
      name: '__global_nav_history',
      segments: [
        {
          name: '__global_back',
          symbol: 'chevron.left',
          width: 34,
        },
        {
          name: '__global_forward',
          symbol: 'chevron.right',
          width: 34,
        },
      ],
    },
    {
      type: 'button',
      name: '__global_reload',
      label: '',
      symbol: isLoading ? 'xmark' : 'arrow.clockwise',
      width: 36,
    },
  ]
}

export async function buildScrubberItemsAsync(windowTabs = []) {
  const favicons = await Promise.all(
    windowTabs.map(tab => getFaviconBase64(tab.favIconUrl))
  )

  let selectedIndex = 0
  const items = windowTabs.map((tab, idx) => {
    if (tab.active) {
      selectedIndex = idx
    }

    let symbol
    if (tab.mutedInfo?.muted) {
      symbol = 'speaker.slash.fill'
    } else if (tab.audible) {
      symbol = 'speaker.wave.2.fill'
    } else if (tab.pinned) {
      symbol = 'pin.fill'
    }

    const favicon = favicons[idx]

    return {
      id: String(tab.id),
      label: truncateLabel(tab.title || tab.url || 'New Tab'),
      ...(favicon ? { favicon } : {}),
      ...(symbol ? { symbol } : {}),
      active: Boolean(tab.active),
    }
  })

  return {
    items,
    selectedIndex: items.length > 0 ? selectedIndex : undefined,
  }
}

export async function buildGlobalRightItemsAsync(activeTab, windowTabs, settings) {
  const items = []

  if (settings.showTabScrubber) {
    const { items: tabItems, selectedIndex } =
      await buildScrubberItemsAsync(windowTabs)
    items.push({
      type: 'scrubber',
      name: '__global_tabs',
      items: tabItems,
      selectedIndex,
    })
  }

  if (settings.showNewTab) {
    items.push({
      type: 'button',
      name: '__global_new_tab',
      label: '',
      symbol: 'plus',
      width: 36,
    })
  }

  if (settings.showExtraTabActions) {
    items.push(
      {
        type: 'button',
        name: '__global_close_tab',
        label: '',
        symbol: 'xmark',
        width: 36,
      },
      {
        type: 'button',
        name: '__global_reopen_tab',
        label: '',
        symbol: 'arrow.uturn.backward',
        width: 36,
      }
    )
  }

  if (settings.showMuteTab) {
    const muted = Boolean(activeTab?.mutedInfo?.muted)
    items.push({
      type: 'button',
      name: '__global_mute_tab',
      label: '',
      symbol: muted ? 'speaker.slash.fill' : 'speaker.wave.2.fill',
      width: 36,
      ...(muted ? { bezelColor: '#c0392b' } : {}),
    })
  }

  return items
}

export async function composeTouchbarLayoutAsync({
  siteLayout,
  activeTab,
  windowTabs,
  settings,
  modeToggle = null,
}) {
  const navItems = settings.showNavigation ? buildNavigationItems(activeTab) : []

  let toggleItem = null
  if (modeToggle === 'to_tabs') {
    toggleItem = {
      type: 'button',
      name: '__global_toggle_mode',
      label: '',
      symbol: 'rectangle.stack',
      width: 36,
    }
  } else if (modeToggle === 'to_media') {
    toggleItem = {
      type: 'button',
      name: '__global_toggle_mode',
      label: '',
      symbol: 'play.rectangle.fill',
      bezelColor: '#0a84ff',
      width: 36,
    }
  }

  const leftItems = toggleItem ? [...navItems, toggleItem] : navItems

  if (siteLayout && siteLayout.length > 0) {
    const baseLeft = settings.mergeNavWithPackets
      ? leftItems
      : toggleItem
        ? [toggleItem]
        : []

    if (baseLeft.length > 0) {
      return [
        ...baseLeft,
        { type: 'spacer', name: '__global_sep', size: 'small' },
        ...siteLayout,
      ]
    }
    return siteLayout
  }

  const rightItems = await buildGlobalRightItemsAsync(
    activeTab,
    windowTabs,
    settings
  )
  if (leftItems.length > 0 && rightItems.length > 0) {
    return [
      ...leftItems,
      { type: 'spacer', name: '__global_sep', size: 'small' },
      ...rightItems,
    ]
  }

  return [...leftItems, ...rightItems]
}

export async function handleGlobalAction(action) {
  const name = action?.name
  if (!name || !name.startsWith('__global_')) return

  if (name === '__global_tabs' && action.itemId) {
    const targetTabId = Number(action.itemId)
    if (Number.isFinite(targetTabId)) {
      await browser.tabs.update(targetTabId, { active: true }).catch(() => {})
    }
    return
  }

  const [activeTab] = await browser.tabs.query({
    active: true,
    currentWindow: true,
  })
  if (!activeTab) return

  switch (name) {
    case '__global_back':
      await browser.tabs.goBack(activeTab.id).catch(() => {})
      break
    case '__global_forward':
      await browser.tabs.goForward(activeTab.id).catch(() => {})
      break
    case '__global_reload':
      if (activeTab.status === 'loading') {
        await browser.tabs
          .executeScript(activeTab.id, {
            code: 'window.stop()',
          })
          .catch(() => browser.tabs.reload(activeTab.id).catch(() => {}))
      } else {
        await browser.tabs.reload(activeTab.id).catch(() => {})
      }
      break
    case '__global_new_tab':
      await browser.tabs.create({ windowId: activeTab.windowId }).catch(() => {})
      break
    case '__global_close_tab':
      await browser.tabs.remove(activeTab.id).catch(() => {})
      break
    case '__global_reopen_tab': {
      const closed = await browser.sessions
        .getRecentlyClosed({ maxResults: 1 })
        .catch(() => [])
      const entry = closed?.[0]
      const sessionId = entry?.tab?.sessionId || entry?.window?.sessionId
      if (sessionId) {
        await browser.sessions.restore(sessionId).catch(() => {})
      }
      break
    }
    case '__global_mute_tab':
      await browser.tabs
        .update(activeTab.id, { muted: !activeTab.mutedInfo?.muted })
        .catch(() => {})
      break
  }
}

export const SETTINGS_VERSION = 2

export const DEFAULT_SETTINGS = {
  settingsVersion: SETTINGS_VERSION,
  replaceNativeTouchBar: true,
  fullWidthMode: false,
  glassStyle: true,
  showNavigation: true,
  showTabScrubber: true,
  showNewTab: true,
  showExtraTabActions: false,
  showMuteTab: false,
  mergeNavWithPackets: true,
  autoPresent: true,
  enableGenericMedia: true,
}

export async function loadSettings() {
  try {
    const stored = await browser.storage.local.get('settings')
    const saved = stored?.settings

    if (!saved || (saved.settingsVersion || 1) < SETTINGS_VERSION) {
      const defaults = { ...DEFAULT_SETTINGS }
      await browser.storage.local.set({ settings: defaults })
      return defaults
    }

    return {
      ...DEFAULT_SETTINGS,
      ...saved,
      settingsVersion: SETTINGS_VERSION,
    }
  } catch (err) {
    console.warn('Failed to load settings, using defaults:', err)
    return { ...DEFAULT_SETTINGS }
  }
}

export async function saveSettings(partial) {
  const current = await loadSettings()
  const updated = {
    ...current,
    ...partial,
    settingsVersion: SETTINGS_VERSION,
  }
  await browser.storage.local.set({ settings: updated })
  return updated
}

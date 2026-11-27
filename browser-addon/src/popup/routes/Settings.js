import { el } from '../dom'

const SETTING_OPTIONS = [
  {
    key: 'glassStyle',
    title: 'Dark Glass Touch Bar',
    description: 'Translucent glass buttons, specular rims, and spring animations',
  },
  {
    key: 'replaceNativeTouchBar',
    title: 'Replace Firefox Touch Bar',
    description: 'Hide Firefox default bar and extra Control Strip icon',
  },
  {
    key: 'fullWidthMode',
    title: 'Full-width Touch Bar',
    description: 'Also cover macOS Control Strip for maximum width',
  },
  {
    key: 'showNavigation',
    title: 'Navigation buttons',
    description: 'Compact Back / Forward segment and Reload button',
  },
  {
    key: 'showTabScrubber',
    title: 'Open tabs scrubber (Edge style)',
    description: 'Scrollable tab switcher with favicons and audio badges',
  },
  {
    key: 'showNewTab',
    title: 'New Tab button',
    description: 'Compact + button on the right side',
  },
  {
    key: 'showExtraTabActions',
    title: 'Close & Reopen Tab buttons',
    description: 'Add Close (×) and Reopen Closed Tab buttons',
  },
  {
    key: 'showMuteTab',
    title: 'Mute tab button',
    description: 'Toggle mute/unmute on the active tab',
  },
  {
    key: 'mergeNavWithPackets',
    title: 'Keep navigation on site packets',
    description:
      'Keep Back/Forward/Reload on the left of YouTube & media controls',
  },
  {
    key: 'autoPresent',
    title: 'Auto-show Touch Bar',
    description: 'Automatically show Touch Bar when switching to Firefox',
  },
  {
    key: 'enableGenericMedia',
    title: 'HTML5 Media controls',
    description: 'Auto-detect playing video/audio on other websites',
  },
]

export function renderSettings({ settings, saving, onToggle }) {
  return el(
    'section',
    { className: 'glass-card settings-container' },
    SETTING_OPTIONS.map(opt =>
      el('label', { className: 'setting-row' }, [
        el('div', { className: 'setting-text' }, [
          el('span', { className: 'setting-title', text: opt.title }),
          el('span', { className: 'setting-description', text: opt.description }),
        ]),
        el('span', { className: 'switch' }, [
          el('input', {
            className: 'sr-only',
            type: 'checkbox',
            'data-setting-key': opt.key,
            checked: Boolean(settings?.[opt.key]),
            disabled: saving,
            onChange: event => onToggle(opt.key, event.currentTarget),
          }),
          el('span', { className: 'switch-track', 'aria-hidden': 'true' }, [
            el('span', { className: 'switch-thumb' }),
          ]),
        ]),
      ])
    )
  )
}

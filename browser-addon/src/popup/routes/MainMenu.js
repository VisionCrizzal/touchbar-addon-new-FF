import { el } from '../dom'

const HELPER_SETUP_URL =
  'https://github.com/VisionCrizzal/touchbar-addon-new-FF#1-build--install-the-native-messaging-host'

export function renderMainMenu({ status, packets, onNavigate }) {
  const connected = Boolean(status?.nativeConnected)
  const modeLabel = status?.activeStatus?.activeLayoutType || 'Global Firefox Bar'

  const nodes = [
    el('small', { className: 'menu-label', text: 'Status' }),
    el('div', { className: 'status-row' }, [
      el(
        'span',
        {
          className: `status-badge ${connected ? 'connected' : 'disconnected'}`,
        },
        [
          el('span', { className: 'status-dot' }),
          connected ? 'Helper Connected' : 'Helper Disconnected',
        ]
      ),
      el('span', { className: 'mode-text', text: modeLabel }),
    ]),
  ]

  if (!connected) {
    nodes.push(
      el('div', { className: 'helper-notice' }, [
        el('div', {
          text: 'Touch Bar rendering requires installing the macOS companion helper (touchbar-browser-helper).',
        }),
        el('button', {
          className: 'helper-link-btn',
          type: 'button',
          text: 'Open macOS Helper Setup Guide',
          onClick: () => {
            browser.tabs
              .create({ url: HELPER_SETUP_URL })
              .catch(() => {})
          },
        }),
      ])
    )
  }

  nodes.push(
    el('hr', { className: 'separator' }),
    el(
      'button',
      {
        className: 'menu-item-btn',
        type: 'button',
        onClick: () => onNavigate('/installed-packets'),
      },
      [
        el('span', { text: `Installed packets (${packets.length})` }),
        el('span', { className: 'menu-item-chevron', text: '›' }),
      ]
    ),
    el(
      'button',
      {
        className: 'menu-item-btn',
        type: 'button',
        onClick: () => onNavigate('/settings'),
      },
      [
        el('span', { text: 'Touch Bar Settings' }),
        el('span', { className: 'menu-item-chevron', text: '›' }),
      ]
    )
  )

  return el('div', {}, nodes)
}

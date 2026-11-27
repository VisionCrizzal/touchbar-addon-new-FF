import { DEFAULT_SETTINGS } from '../settings'
import {
  addPopupMessageListener,
  getSettings,
  getStatus,
  getTouchbarPackets,
  updateSettings,
} from './backgroundApi'
import { createNavigationHeader } from './components/NavigationHeader'
import { el } from './dom'
import { renderInstalledPackets } from './routes/InstalledPackets'
import { renderMainMenu } from './routes/MainMenu'
import { renderSettings } from './routes/Settings'

const root = document.querySelector('#app')

const state = {
  route: '/',
  transitionDirection: 'none',
  packets: [],
  settings: { ...DEFAULT_SETTINGS },
  status: null,
  saving: false,
}

function navigate(nextRoute) {
  if (nextRoute === state.route) return
  state.transitionDirection = nextRoute === '/' ? 'back' : 'forward'
  state.route = nextRoute
  render()
}

async function handleToggleSetting(key, inputEl) {
  if (!state.settings) return
  if (state.saving) {
    if (inputEl) inputEl.checked = Boolean(state.settings[key])
    return
  }

  const nextValue = inputEl ? Boolean(inputEl.checked) : !state.settings[key]
  const nextPartial = { [key]: nextValue }
  state.settings = { ...state.settings, ...nextPartial }
  state.saving = true
  if (inputEl) inputEl.disabled = true

  try {
    const updated = await updateSettings(nextPartial)
    if (updated && typeof updated === 'object') {
      state.settings = updated
    }
  } finally {
    state.saving = false
    if (inputEl) {
      inputEl.checked = Boolean(state.settings[key])
      inputEl.disabled = false
    }
  }
}

function render() {
  if (!root) return
  const scrollY = window.scrollY
  const animClass =
    state.transitionDirection === 'forward'
      ? 'view-panel enter-forward'
      : state.transitionDirection === 'back'
        ? 'view-panel enter-back'
        : 'view-panel'
  state.transitionDirection = 'none'

  if (state.route === '/installed-packets') {
    const shell = el('div', { className: `popup-shell ${animClass}` }, [
      createNavigationHeader('Installed Packets', () => navigate('/')),
      renderInstalledPackets({ packets: state.packets }),
    ])
    root.replaceChildren(shell)
    window.scrollTo(0, 0)
    return
  }

  if (state.route === '/settings') {
    const shell = el('div', { className: `popup-shell ${animClass}` }, [
      createNavigationHeader('Settings', () => navigate('/')),
      renderSettings({
        settings: state.settings,
        saving: state.saving,
        onToggle: handleToggleSetting,
      }),
    ])
    root.replaceChildren(shell)
    window.scrollTo(0, scrollY)
    return
  }

  const shell = el('div', { className: `popup-shell ${animClass}` }, [
    renderMainMenu({
      status: state.status,
      packets: state.packets,
      onNavigate: navigate,
    }),
  ])
  root.replaceChildren(shell)
  window.scrollTo(0, 0)
}

async function bootstrap() {
  render()

  const [packets, settings, status] = await Promise.all([
    getTouchbarPackets().catch(() => null),
    getSettings().catch(() => null),
    getStatus().catch(() => null),
  ])

  if (Array.isArray(packets)) state.packets = packets
  if (settings && typeof settings === 'object') state.settings = settings
  if (status && typeof status === 'object') state.status = status
  render()

  addPopupMessageListener(message => {
    if (message.type === 'active_packet_changed') {
      getStatus()
        .then(res => {
          if (res && typeof res === 'object') {
            state.status = res
            if (state.route === '/') {
              render()
            }
          }
        })
        .catch(() => {})
    }
  })
}

bootstrap()

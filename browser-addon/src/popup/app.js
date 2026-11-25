import { DEFAULT_SETTINGS } from '../settings'
import {
  addPopupMessageListener,
  getSettings,
  getStatus,
  getTouchbarPackets,
  updateSettings,
} from './backgroundApi'
import { createNavigationHeader } from './components/NavigationHeader'
import { renderInstalledPackets } from './routes/InstalledPackets'
import { renderMainMenu } from './routes/MainMenu'
import { renderSettings } from './routes/Settings'

const root = document.querySelector('#app')

const state = {
  route: '/',
  packets: [],
  settings: { ...DEFAULT_SETTINGS },
  status: null,
  saving: false,
}

function navigate(nextRoute) {
  state.route = nextRoute
  render()
}

async function handleToggleSetting(key) {
  if (state.saving || !state.settings) return
  const nextPartial = { [key]: !state.settings[key] }
  state.settings = { ...state.settings, ...nextPartial }
  state.saving = true
  render()

  try {
    const updated = await updateSettings(nextPartial)
    if (updated && typeof updated === 'object') {
      state.settings = updated
    }
  } finally {
    state.saving = false
    render()
  }
}

function render() {
  if (!root) return
  const scrollY = window.scrollY

  if (state.route === '/installed-packets') {
    root.replaceChildren(
      createNavigationHeader('Installed Packets', () => navigate('/')),
      renderInstalledPackets({ packets: state.packets })
    )
    window.scrollTo(0, 0)
    return
  }

  if (state.route === '/settings') {
    root.replaceChildren(
      createNavigationHeader('Settings', () => navigate('/')),
      renderSettings({
        settings: state.settings,
        saving: state.saving,
        onToggle: handleToggleSetting,
      })
    )
    window.scrollTo(0, scrollY)
    return
  }

  root.replaceChildren(
    renderMainMenu({
      status: state.status,
      packets: state.packets,
      onNavigate: navigate,
    })
  )
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
            render()
          }
        })
        .catch(() => {})
    }
  })
}

bootstrap()

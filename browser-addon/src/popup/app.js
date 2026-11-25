import React, { useState, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import { createGlobalStyle } from 'styled-components'
import { MemoryRouter as Router, Routes, Route } from 'react-router-dom'
import MainMenu from './routes/MainMenu'
import NavigationHeader from './components/NavigationHeader'
import {
  addPopupMessageListener,
  getSettings,
  getStatus,
  getTouchbarPackets,
  removePopupMessageListener,
} from './backgroundApi'
import InstalledPackets from './routes/InstalledPackets'
import Settings from './routes/Settings'
import { DEFAULT_SETTINGS } from '../settings'

const GlobalStyles = createGlobalStyle`
  body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    width: 100%;
    min-width: 360px;
    color: #1c1c1e;
  }
`

export const PopupContext = React.createContext({
  touchbarPackets: [],
  settings: DEFAULT_SETTINGS,
  setSettings: () => {},
  status: null,
})

const App = () => {
  const [packets, setPackets] = useState([])
  const [settings, setSettings] = useState(DEFAULT_SETTINGS)
  const [status, setStatus] = useState(null)

  useEffect(() => {
    getTouchbarPackets().then(res => {
      if (Array.isArray(res)) setPackets(res)
    })
    getSettings().then(res => {
      if (res && typeof res === 'object') setSettings(res)
    })
    getStatus().then(res => {
      if (res && typeof res === 'object') setStatus(res)
    })

    const popupListener = message => {
      if (message.type === 'active_packet_changed') {
        getStatus().then(res => {
          if (res && typeof res === 'object') setStatus(res)
        })
      }
    }

    addPopupMessageListener(popupListener)

    return () => {
      removePopupMessageListener(popupListener)
    }
  }, [])

  return (
    <PopupContext.Provider
      value={{ touchbarPackets: packets, settings, setSettings, status }}
    >
      <Router initialEntries={['/']}>
        <GlobalStyles />
        <Routes>
          <Route path="/" element={<MainMenu />} />
          <Route
            path="/installed-packets"
            element={
              <div>
                <NavigationHeader title="Installed Packets" />
                <InstalledPackets />
              </div>
            }
          />
          <Route
            path="/settings"
            element={
              <div>
                <NavigationHeader title="Settings" />
                <Settings />
              </div>
            }
          />
          <Route path="*" element={<MainMenu />} />
        </Routes>
      </Router>
    </PopupContext.Provider>
  )
}

const appElement = document.querySelector('#app')
createRoot(appElement).render(<App />)

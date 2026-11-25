import React, { useContext, useState } from 'react'
import styled from 'styled-components'
import { PopupContext } from '../app'
import { updateSettings } from '../backgroundApi'

const Container = styled.div`
  padding: 4px 0 8px;
`

const SettingRow = styled.label`
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 12px;
  cursor: pointer;

  &:hover {
    background-color: #f4f4f6;
  }
`

const TextBlock = styled.div`
  display: flex;
  flex-direction: column;
`

const Title = styled.span`
  font-size: 0.92rem;
  font-weight: 500;
  color: #1c1c1e;
`

const Description = styled.span`
  font-size: 0.78rem;
  color: #6e6e73;
  margin-top: 2px;
`

const Toggle = styled.input`
  width: 16px;
  height: 16px;
  cursor: pointer;
  flex-shrink: 0;
`

const SETTING_OPTIONS = [
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
    description: 'Keep Back/Forward/Reload on the left of YouTube & media controls',
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

const Settings = () => {
  const { settings, setSettings } = useContext(PopupContext)
  const [saving, setSaving] = useState(false)

  const handleToggle = async key => {
    if (saving || !settings) return
    const nextPartial = { [key]: !settings[key] }
    setSettings(prev => ({ ...prev, ...nextPartial }))
    setSaving(true)
    try {
      const updated = await updateSettings(nextPartial)
      if (updated) {
        setSettings(updated)
      }
    } finally {
      setSaving(false)
    }
  }

  return (
    <Container>
      {SETTING_OPTIONS.map(opt => (
        <SettingRow key={opt.key}>
          <TextBlock>
            <Title>{opt.title}</Title>
            <Description>{opt.description}</Description>
          </TextBlock>
          <Toggle
            type="checkbox"
            checked={Boolean(settings?.[opt.key])}
            onChange={() => handleToggle(opt.key)}
          />
        </SettingRow>
      ))}
    </Container>
  )
}

export default Settings

import React, { useContext } from 'react'
import styled from 'styled-components'
import { PopupContext } from '../app'

import MenuItem from '../components/MenuItem'
import MenuLabel from '../components/MenuLabel'
import Separator from '../components/MenuSeparator'

const StatusRow = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  font-size: 0.9rem;
`

const StatusBadge = styled.span`
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-weight: 600;
  color: ${props => (props.$connected ? '#1e8e3e' : '#c5221f')};
`

const Dot = styled.span`
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: ${props => (props.$connected ? '#1e8e3e' : '#c5221f')};
`

const ModeText = styled.span`
  color: #555;
  font-size: 0.85rem;
`

const MainMenu = () => {
  const { status, touchbarPackets } = useContext(PopupContext)
  const connected = Boolean(status?.nativeConnected)
  const modeLabel = status?.activeStatus?.activeLayoutType || 'Global Firefox Bar'

  return (
    <div>
      <MenuLabel>Status</MenuLabel>
      <StatusRow>
        <StatusBadge $connected={connected}>
          <Dot $connected={connected} />
          {connected ? 'Helper Connected' : 'Helper Disconnected'}
        </StatusBadge>
        <ModeText>{modeLabel}</ModeText>
      </StatusRow>
      <Separator />
      <MenuItem
        label={`Installed packets (${touchbarPackets.length})`}
        navigateTo="/installed-packets"
      />
      <MenuItem label="Touch Bar Settings" navigateTo="/settings" />
    </div>
  )
}

export default MainMenu

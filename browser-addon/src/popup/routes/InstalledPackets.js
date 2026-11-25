import { el } from '../dom'

export function renderInstalledPackets({ packets }) {
  return el(
    'div',
    {},
    packets.map(packet =>
      el('div', { className: 'menu-item-row' }, [
        el('span', { text: packet.headers?.name || packet.id || 'Packet' }),
        el('span', {
          className: 'packet-meta',
          text: `${packet.headers?.match?.length || 0} rule(s)`,
        }),
      ])
    )
  )
}

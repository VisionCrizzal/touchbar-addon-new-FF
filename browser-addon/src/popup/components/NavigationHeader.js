import { el } from '../dom'

export function createNavigationHeader(title, onBack) {
  return el('nav', { className: 'nav-header' }, [
    el(
      'button',
      {
        className: 'back-btn',
        type: 'button',
        'aria-label': 'Back',
        onClick: onBack,
      },
      [el('img', { src: './assets/icon-back.svg', alt: 'Back' })]
    ),
    el('h1', { className: 'nav-title', text: title }),
  ])
}

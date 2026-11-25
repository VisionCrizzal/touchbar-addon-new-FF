/**
 * Safe DOM element creation utilities using createElement and textContent only
 */

export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag)

  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === null || value === false) continue

    if (key === 'className') {
      node.className = String(value)
    } else if (key === 'text') {
      node.textContent = String(value)
    } else if (key === 'checked' || key === 'disabled') {
      node[key] = Boolean(value)
    } else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2).toLowerCase(), value)
    } else {
      node.setAttribute(key, String(value))
    }
  }

  for (const child of children) {
    if (child === undefined || child === null || child === false) continue
    node.appendChild(
      typeof child === 'string' || typeof child === 'number'
        ? document.createTextNode(String(child))
        : child
    )
  }

  return node
}

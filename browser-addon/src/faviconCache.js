const MAX_CACHE = 150
const cache = new Map()

function setCached(key, value) {
  if (cache.size >= MAX_CACHE) {
    const oldestKey = cache.keys().next().value
    if (oldestKey !== undefined) {
      cache.delete(oldestKey)
    }
  }
  cache.set(key, value)
}

export async function getFaviconBase64(favIconUrl) {
  if (
    !favIconUrl ||
    typeof favIconUrl !== 'string' ||
    favIconUrl.startsWith('chrome://') ||
    favIconUrl.startsWith('resource://')
  ) {
    return null
  }

  if (cache.has(favIconUrl)) {
    return cache.get(favIconUrl)
  }

  const base64 = await new Promise(resolve => {
    let settled = false
    const finish = value => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      resolve(value)
    }

    const timer = setTimeout(() => {
      finish(null)
    }, 1500)

    const img = new Image()
    img.crossOrigin = 'anonymous'

    img.onload = () => {
      try {
        const canvas = document.createElement('canvas')
        canvas.width = 32
        canvas.height = 32
        const ctx = canvas.getContext('2d')
        if (!ctx) {
          finish(null)
          return
        }
        ctx.clearRect(0, 0, 32, 32)
        ctx.drawImage(img, 0, 0, 32, 32)
        const dataUrl = canvas.toDataURL('image/png')
        const prefix = 'data:image/png;base64,'
        if (dataUrl.startsWith(prefix)) {
          finish(dataUrl.slice(prefix.length))
          return
        }
      } catch {
        // Fallback below if canvas is tainted
      }

      const prefix = 'data:image/png;base64,'
      if (favIconUrl.startsWith(prefix) && favIconUrl.length < 16000) {
        finish(favIconUrl.slice(prefix.length))
      } else {
        finish(null)
      }
    }

    img.onerror = () => {
      const prefix = 'data:image/png;base64,'
      if (favIconUrl.startsWith(prefix) && favIconUrl.length < 16000) {
        finish(favIconUrl.slice(prefix.length))
      } else {
        finish(null)
      }
    }

    img.src = favIconUrl
  })

  setCached(favIconUrl, base64)
  return base64
}

const storage = browser.storage.local

export const addPacket = async ({ name, script, enabled = true, path }) => {
  const packet = { name, script, enabled, path }
  const key = crypto.randomUUID()

  const { packets = {} } = await storage.get('packets')
  packets[key] = packet

  await storage.set({
    packets,
  })

  return {
    key,
    packet,
  }
}

export const getPacket = async key => {
  const { packets = {} } = await storage.get('packets')
  return packets[key]
}

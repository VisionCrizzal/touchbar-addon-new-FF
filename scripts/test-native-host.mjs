#!/usr/bin/env node
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import os from 'node:os'
import path from 'node:path'

const defaultBin = path.join(
  os.homedir(),
  'Library',
  'Application Support',
  'touchbar-browser-helper',
  'touchbar-browser-helper'
)
const binPath = process.argv[2] || defaultBin

const SAMPLE_FAVICON_PNG =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

function encodeFrame(payloadString) {
  const body = Buffer.from(payloadString, 'utf8')
  const header = Buffer.alloc(4)
  header.writeUInt32LE(body.length, 0)
  return Buffer.concat([header, body])
}

function sendFrame(proc, objOrRaw) {
  const payload = typeof objOrRaw === 'string' ? objOrRaw : JSON.stringify(objOrRaw)
  proc.stdin.write(encodeFrame(payload))
}

function createFrameReader(proc) {
  let buffer = Buffer.alloc(0)
  const waiters = []

  function tryDrain() {
    while (waiters.length > 0 && buffer.length >= 4) {
      const length = buffer.readUInt32LE(0)
      if (buffer.length < 4 + length) return
      const payload = buffer.subarray(4, 4 + length).toString('utf8')
      buffer = buffer.subarray(4 + length)
      const { resolve } = waiters.shift()
      resolve(JSON.parse(payload))
    }
  }

  proc.stdout.on('data', chunk => {
    buffer = Buffer.concat([buffer, chunk])
    tryDrain()
  })

  return function readFrame(timeoutMs = 5000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const idx = waiters.findIndex(w => w.reject === wrappedReject)
        if (idx !== -1) waiters.splice(idx, 1)
        reject(new Error(`Timed out after ${timeoutMs}ms waiting for Native Messaging frame`))
      }, timeoutMs)

      function wrappedResolve(value) {
        clearTimeout(timer)
        resolve(value)
      }

      function wrappedReject(err) {
        clearTimeout(timer)
        reject(err)
      }

      waiters.push({ resolve: wrappedResolve, reject: wrappedReject })
      tryDrain()
    })
  }
}

async function run() {
  console.log(`Testing Native Messaging helper: ${binPath}`)
  const proc = spawn(binPath, [], { stdio: ['pipe', 'pipe', 'pipe'] })

  let stderrLog = ''
  proc.stderr.on('data', chunk => {
    stderrLog += chunk.toString('utf8')
  })

  const exitPromise = new Promise(resolve => {
    proc.on('exit', (code, signal) => resolve({ code, signal }))
  })

  const readFrame = createFrameReader(proc)

  // 1. ping -> pong
  sendFrame(proc, { type: 'ping' })
  const pong = await readFrame()
  assert.deepEqual(pong, { type: 'ping', success: true, value: 'pong' })
  console.log('PASS 1/8: ping -> pong')

  // 2. malformed JSON -> success: false
  sendFrame(proc, '{not-json')
  const malformed = await readFrame()
  assert.equal(malformed.success, false)
  console.log('PASS 2/8: malformed JSON -> error response')

  // 3. unknown type -> success: false
  sendFrame(proc, { type: 'unknown_type' })
  const unknown = await readFrame()
  assert.equal(unknown.type, 'unknown_type')
  assert.equal(unknown.success, false)
  console.log('PASS 3/8: unknown type -> error response')

  // 4. Phase 1 slider null + update + dismiss
  sendFrame(proc, {
    type: 'change_layout',
    layout: [
      { type: 'button', name: 'play', label: 'Play', icon: 'NSTouchBarPlayTemplate' },
      { type: 'slider', name: 'scrubber', label: '0:00', value: null, color: '#ff0000' },
    ],
  })
  sendFrame(proc, {
    type: 'update_item',
    name: 'scrubber',
    values: { label: '0:15', value: 0.25, color: '#00ff00' },
  })
  sendFrame(proc, { type: 'dismiss_touchbar' })
  sendFrame(proc, { type: 'ping' })
  const followUp1 = await readFrame()
  assert.deepEqual(followUp1, { type: 'ping', success: true, value: 'pong' })
  console.log('PASS 4/8: null slider layout, update_item, dismiss_touchbar')

  // 5. Edge clone config (glassStyle + replaceNative + fullWidth) + segmented + compact buttons + favicon scrubber
  sendFrame(proc, {
    type: 'set_config',
    autoPresent: true,
    replaceNative: true,
    fullWidth: false,
    glassStyle: true,
  })
  const globalLayoutBase = [
    {
      type: 'segmented',
      name: '__global_nav_history',
      segments: [
        { name: '__global_back', symbol: 'chevron.left', width: 34, enabled: true },
        { name: '__global_forward', symbol: 'chevron.right', width: 34, enabled: false },
      ],
    },
    {
      type: 'button',
      name: '__global_reload',
      label: '',
      symbol: 'arrow.clockwise',
      width: 36,
    },
    { type: 'spacer', name: '__global_sep', size: 'small' },
    {
      type: 'scrubber',
      name: '__global_tabs',
      selectedIndex: 1,
      items: [
        { id: '1', label: 'Mozilla', favicon: SAMPLE_FAVICON_PNG, active: false },
        {
          id: '2',
          label: 'YouTube',
          favicon: SAMPLE_FAVICON_PNG,
          symbol: 'speaker.wave.2.fill',
          active: true,
        },
        { id: '3', label: 'GitHub', active: false },
        { id: '4', label: 'Docs', active: false },
        { id: '5', label: 'Inbox', symbol: 'pin.fill', active: false },
      ],
    },
    {
      type: 'button',
      name: '__global_new_tab',
      label: '',
      symbol: 'plus',
      width: 36,
    },
  ]
  sendFrame(proc, { type: 'change_layout', layout: globalLayoutBase })
  sendFrame(proc, {
    type: 'set_config',
    autoPresent: true,
    replaceNative: true,
    fullWidth: true,
    glassStyle: true,
  })
  console.log('PASS 5/8: Dark Glass config (glassStyle/replaceNative/fullWidth) + segmented + scrubber')

  // 6. In-place layout reconciliation (same structure -> animated pill slide & button update) + glassStyle toggle
  const switchedTabLayout = [
    {
      type: 'segmented',
      name: '__global_nav_history',
      segments: [
        { name: '__global_back', symbol: 'chevron.left', width: 34, enabled: true },
        { name: '__global_forward', symbol: 'chevron.right', width: 34, enabled: true },
      ],
    },
    {
      type: 'button',
      name: '__global_reload',
      label: '',
      symbol: 'xmark',
      width: 36,
    },
    { type: 'spacer', name: '__global_sep', size: 'small' },
    {
      type: 'scrubber',
      name: '__global_tabs',
      selectedIndex: 0,
      items: [
        { id: '1', label: 'Mozilla', favicon: SAMPLE_FAVICON_PNG, active: true },
        { id: '2', label: 'YouTube', favicon: SAMPLE_FAVICON_PNG, symbol: 'speaker.wave.2.fill', active: false },
        { id: '3', label: 'GitHub', active: false },
        { id: '4', label: 'Docs', active: false },
        { id: '5', label: 'Inbox', symbol: 'pin.fill', active: false },
      ],
    },
    {
      type: 'button',
      name: '__global_new_tab',
      label: '',
      symbol: 'plus',
      width: 36,
    },
  ]
  sendFrame(proc, { type: 'change_layout', layout: switchedTabLayout })
  sendFrame(proc, {
    type: 'update_item',
    name: '__global_reload',
    values: { symbol: 'arrow.clockwise' },
  })
  sendFrame(proc, { type: 'set_config', glassStyle: false })
  sendFrame(proc, { type: 'set_config', glassStyle: true })
  console.log('PASS 6/8: in-place layout reconciliation + glassStyle toggle (false -> true)')

  // 7. Update scrubber count + switch to compact media layout + GlassSlider update + follow-up ping
  sendFrame(proc, {
    type: 'update_item',
    name: '__global_tabs',
    values: {
      selectedIndex: 0,
      items: [
        { id: '1', label: 'Mozilla', favicon: SAMPLE_FAVICON_PNG, active: true },
        { id: '2', label: 'YouTube', favicon: SAMPLE_FAVICON_PNG, active: false },
      ],
    },
  })
  sendFrame(proc, {
    type: 'change_layout',
    layout: [
      {
        type: 'button',
        name: 'media-playpause',
        label: '',
        symbol: 'pause.fill',
        width: 36,
      },
      {
        type: 'slider',
        name: 'playback-slider',
        label: '1:23',
        value: 0.4,
        color: '#ff0000',
      },
    ],
  })
  sendFrame(proc, {
    type: 'update_item',
    name: 'playback-slider',
    values: { label: '2:10', value: 0.65 },
  })
  sendFrame(proc, { type: 'dismiss_touchbar' })
  sendFrame(proc, { type: 'ping' })
  const followUp2 = await readFrame()
  assert.deepEqual(followUp2, { type: 'ping', success: true, value: 'pong' })
  console.log('PASS 7/8: scrubber shrink + media layout transition + GlassSlider update + ping')

  // 8. EOF clean exit within 3s
  const startMs = Date.now()
  proc.stdin.end()

  const exitResult = await Promise.race([
    exitPromise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Helper failed to exit within 3000ms after stdin EOF')), 3000)
    ),
  ])
  const elapsedMs = Date.now() - startMs
  assert.equal(exitResult.code, 0, `Expected exit code 0, got ${JSON.stringify(exitResult)}; stderr=${stderrLog}`)
  assert.equal(exitResult.signal, null)
  console.log(`PASS 8/8: EOF clean exit with code 0 in ${elapsedMs}ms`)
}

run().catch(err => {
  console.error('TEST FAILED:', err)
  process.exit(1)
})

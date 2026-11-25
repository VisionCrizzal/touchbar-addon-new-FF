import * as esbuild from 'esbuild'
import { cpSync, mkdirSync, rmSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '..')
const distDir = path.join(rootDir, 'dist')
const staticDir = path.join(rootDir, 'static')
const watch = process.argv.includes('--watch')

const PACKET_FILES = [
  ['youtube.touchbar-packet', 'youtube.js'],
  ['github.touchbar-packet', 'github.js'],
  ['google.touchbar-packet', 'google.js'],
  ['facebook.touchbar-packet', 'facebook.js'],
  ['generic-media.touchbar-packet', 'generic-media.js'],
]

function copyStaticAssets() {
  mkdirSync(distDir, { recursive: true })
  cpSync(staticDir, distDir, { recursive: true })
  cpSync(path.join(rootDir, 'src', 'popup.html'), path.join(distDir, 'popup.html'))
  cpSync(path.join(rootDir, 'src', 'popup.css'), path.join(distDir, 'popup.css'))
  cpSync(path.join(rootDir, 'src', 'stopPage.js'), path.join(distDir, 'stopPage.js'))

  const assetsDistDir = path.join(distDir, 'assets')
  mkdirSync(assetsDistDir, { recursive: true })
  cpSync(
    path.join(rootDir, 'src', 'popup', 'assets', 'icon-back.svg'),
    path.join(assetsDistDir, 'icon-back.svg')
  )

  const packetsDistDir = path.join(distDir, 'packets')
  mkdirSync(packetsDistDir, { recursive: true })
  for (const [srcName, destName] of PACKET_FILES) {
    cpSync(
      path.join(rootDir, 'src', 'touchbar-packets', srcName),
      path.join(packetsDistDir, destName)
    )
  }
}

rmSync(distDir, { recursive: true, force: true })
copyStaticAssets()

const commonOptions = {
  bundle: true,
  format: 'iife',
  target: ['firefox115'],
  logLevel: 'info',
  sourcemap: watch ? 'inline' : false,
  minify: false,
}

const buildConfigs = [
  {
    ...commonOptions,
    entryPoints: [path.join(rootDir, 'src', 'background.js')],
    outfile: path.join(distDir, 'background.js'),
  },
  {
    ...commonOptions,
    entryPoints: [path.join(rootDir, 'src', 'contentTouchbarBridge.js')],
    outfile: path.join(distDir, 'contentTouchbarBridge.js'),
  },
  {
    ...commonOptions,
    entryPoints: [path.join(rootDir, 'src', 'popup', 'app.js')],
    outfile: path.join(distDir, 'popup.js'),
  },
]

if (watch) {
  const contexts = await Promise.all(buildConfigs.map(cfg => esbuild.context(cfg)))
  await Promise.all(contexts.map(ctx => ctx.watch()))
  console.log('Watching browser-addon sources...')
} else {
  await Promise.all(buildConfigs.map(cfg => esbuild.build(cfg)))
}

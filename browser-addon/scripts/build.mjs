import * as esbuild from 'esbuild'
import { cpSync, mkdirSync, rmSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '..')
const distDir = path.join(rootDir, 'dist')
const staticDir = path.join(rootDir, 'static')
const watch = process.argv.includes('--watch')

function copyStaticAssets() {
  mkdirSync(distDir, { recursive: true })
  cpSync(staticDir, distDir, { recursive: true })
  cpSync(path.join(rootDir, 'src', 'popup.html'), path.join(distDir, 'popup.html'))

  const packetsDistDir = path.join(distDir, 'packets')
  mkdirSync(packetsDistDir, { recursive: true })
  cpSync(
    path.join(rootDir, 'src', 'touchbar-packets', 'youtube.touchbar-packet'),
    path.join(packetsDistDir, 'youtube.js')
  )
  cpSync(
    path.join(rootDir, 'src', 'touchbar-packets', 'generic-media.touchbar-packet'),
    path.join(packetsDistDir, 'generic-media.js')
  )
}

rmSync(distDir, { recursive: true, force: true })
copyStaticAssets()

const commonOptions = {
  bundle: true,
  format: 'iife',
  target: ['firefox115'],
  logLevel: 'info',
  sourcemap: watch ? 'inline' : false,
  minify: !watch,
}

const buildConfigs = [
  {
    ...commonOptions,
    entryPoints: [path.join(rootDir, 'src', 'background.js')],
    outfile: path.join(distDir, 'background.js'),
    loader: {
      '.touchbar-packet': 'text',
    },
  },
  {
    ...commonOptions,
    entryPoints: [path.join(rootDir, 'src', 'touchbarScriptAPI.js')],
    outfile: path.join(distDir, 'touchbarScriptAPI.js'),
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
    jsx: 'automatic',
    loader: {
      '.js': 'jsx',
      '.svg': 'dataurl',
    },
  },
]

if (watch) {
  const contexts = await Promise.all(buildConfigs.map(cfg => esbuild.context(cfg)))
  await Promise.all(contexts.map(ctx => ctx.watch()))
  console.log('Watching browser-addon sources...')
} else {
  await Promise.all(buildConfigs.map(cfg => esbuild.build(cfg)))
}

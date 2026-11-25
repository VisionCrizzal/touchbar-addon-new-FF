import { execFileSync } from 'node:child_process'
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '..')
const artifactsDir = path.join(rootDir, 'web-ext-artifacts')

const ALLOWED_ENTRIES = [
  'package.json',
  'package-lock.json',
  'amo-metadata.json',
  'scripts',
  'src',
  'static',
]

function filterSourceEntry(srcPath) {
  const base = path.basename(srcPath)
  return base !== '.DS_Store' && !base.startsWith('.env')
}

/**
 * Packages clean extension source files and reproducible build instructions into a zip archive for AMO review.
 * @returns {string} Path to the generated source archive.
 */
export function packageSourceArchive() {
  const manifestPath = path.join(rootDir, 'static', 'manifest.json')
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const version = manifest.version || '0.0.0'
  const archiveName = `touchbar_addon_for_firefox-${version}-source.zip`
  const outputPath = path.join(artifactsDir, archiveName)

  const stageDir = mkdtempSync(path.join(os.tmpdir(), 'touchbar-amo-src-'))

  try {
    for (const entry of ALLOWED_ENTRIES) {
      const srcPath = path.join(rootDir, entry)
      if (!existsSync(srcPath)) continue
      cpSync(srcPath, path.join(stageDir, entry), {
        recursive: true,
        filter: filterSourceEntry,
      })
    }

    const buildReadme = [
      'Touchbar Addon for Firefox - Reproducible Source Build Instructions (AMO)',
      '=========================================================================',
      '',
      `Tested Runtime: Node.js ${process.version} & npm`,
      'Bundler: esbuild (configured in scripts/build.mjs with minify: false)',
      '',
      'Build Steps:',
      '  1. Run: npm ci',
      '  2. Run: npm run build',
      '',
      'Output:',
      '  Unminified WebExtension files matching the submitted .zip/.xpi are generated in ./dist/',
      '',
    ].join('\n')

    writeFileSync(path.join(stageDir, 'README-BUILD.txt'), buildReadme, 'utf8')

    mkdirSync(artifactsDir, { recursive: true })
    rmSync(outputPath, { force: true })

    execFileSync('zip', ['-r', '-q', outputPath, '.'], { cwd: stageDir })
    console.log(`Created AMO source archive: ${outputPath}`)
    return outputPath
  } finally {
    rmSync(stageDir, { recursive: true, force: true })
  }
}

const isDirectRun =
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url

if (isDirectRun) {
  packageSourceArchive()
}

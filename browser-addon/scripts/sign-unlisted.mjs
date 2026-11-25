import { spawnSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { packageSourceArchive } from './package-source.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '..')
const artifactsDir = path.join(rootDir, 'web-ext-artifacts')
const envFilePath = path.join(rootDir, '.env.amo')

function parseEnvFile(filePath) {
  if (!existsSync(filePath)) return {}
  const parsed = {}
  const lines = readFileSync(filePath, 'utf8').split(/\r?\n/)
  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const eqIndex = line.indexOf('=')
    if (eqIndex <= 0) continue
    const key = line.slice(0, eqIndex).trim()
    let value = line.slice(eqIndex + 1).trim()
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1)
    }
    parsed[key] = value
  }
  return parsed
}

function runCommand(cmd, args, env = process.env) {
  const result = spawnSync(cmd, args, {
    cwd: rootDir,
    stdio: 'inherit',
    env,
  })
  if (result.error) {
    console.error(`Failed to run ${cmd}: ${result.error.message}`)
    process.exit(1)
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1)
  }
}

const cliArgs = new Set(process.argv.slice(2))
const dryRun = cliArgs.has('--dry-run')
const noSource = cliArgs.has('--no-source')

const fileEnv = parseEnvFile(envFilePath)
const apiKey =
  process.env.WEB_EXT_API_KEY ||
  process.env.AMO_JWT_ISSUER ||
  fileEnv.WEB_EXT_API_KEY ||
  fileEnv.AMO_JWT_ISSUER ||
  ''
const apiSecret =
  process.env.WEB_EXT_API_SECRET ||
  process.env.AMO_JWT_SECRET ||
  fileEnv.WEB_EXT_API_SECRET ||
  fileEnv.AMO_JWT_SECRET ||
  ''

if (!dryRun && (!apiKey || !apiSecret)) {
  console.error(
    [
      'Error: Missing Mozilla Add-ons (AMO) JWT credentials.',
      '',
      '1. Generate API credentials at:',
      '   https://addons.mozilla.org/developers/addon/api/key/',
      '',
      '2. Provide credentials via environment variables:',
      '   WEB_EXT_API_KEY=user:12345678:901 WEB_EXT_API_SECRET=your-secret npm run sign:unlisted',
      '',
      `   OR save them in ${envFilePath} (gitignored):`,
      '   WEB_EXT_API_KEY=user:12345678:901',
      '   WEB_EXT_API_SECRET=your-secret-here',
    ].join('\n')
  )
  process.exit(1)
}

runCommand('node', ['scripts/build.mjs'])
runCommand('npx', ['web-ext', 'lint', '-s', './dist'])

let sourceZipPath = null
if (!noSource) {
  sourceZipPath = packageSourceArchive()
}

const signArgs = [
  'web-ext',
  'sign',
  '--channel=unlisted',
  '-s',
  './dist',
  '-a',
  './web-ext-artifacts',
]

if (sourceZipPath) {
  signArgs.push('--upload-source-code', sourceZipPath)
}

if (dryRun) {
  console.log(
    `[dry-run] Would run: npx ${signArgs.join(' ')} (using WEB_EXT_API_KEY / WEB_EXT_API_SECRET env vars)`
  )
  process.exit(0)
}

const nodeFlags = [
  '--dns-result-order=ipv4first',
  '--network-family-autoselection-attempt-timeout=2000',
]
const existingNodeOptions = process.env.NODE_OPTIONS || ''
const missingNodeFlags = nodeFlags.filter(
  flag => !existingNodeOptions.includes(flag.split('=')[0])
)
const signNodeOptions = [existingNodeOptions, ...missingNodeFlags]
  .filter(Boolean)
  .join(' ')

const signEnv = {
  ...process.env,
  NODE_OPTIONS: signNodeOptions,
  WEB_EXT_API_KEY: apiKey,
  WEB_EXT_API_SECRET: apiSecret,
}

runCommand('npx', signArgs, signEnv)

const xpiFiles = existsSync(artifactsDir)
  ? readdirSync(artifactsDir)
      .filter(name => name.endsWith('.xpi'))
      .map(name => path.join(artifactsDir, name))
  : []

console.log('\nAMO Unlisted signing succeeded!')
if (xpiFiles.length > 0) {
  console.log('Signed .xpi artifact(s):')
  for (const xpi of xpiFiles) {
    console.log(`  - ${xpi}`)
  }
}
console.log(
  [
    '',
    'Next steps to install permanently in Firefox:',
    '  1. Remove the temporary add-on in about:debugging (or restart Firefox).',
    '  2. Open about:addons -> gear icon -> Install Add-on From File...',
    '  3. Select the signed .xpi in browser-addon/web-ext-artifacts/.',
  ].join('\n')
)

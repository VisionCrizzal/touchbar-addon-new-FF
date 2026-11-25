import { spawnSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { packageSourceArchive } from '../package-source.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '../..')
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

function buildSignNodeOptions() {
  const nodeFlags = [
    '--dns-result-order=ipv4first',
    '--network-family-autoselection-attempt-timeout=2000',
  ]
  const existingNodeOptions = process.env.NODE_OPTIONS || ''
  const missingNodeFlags = nodeFlags.filter(
    flag => !existingNodeOptions.includes(flag.split('=')[0])
  )
  return [existingNodeOptions, ...missingNodeFlags].filter(Boolean).join(' ')
}

/**
 * Runs build, lint, source archiving, and `web-ext sign` for a specified AMO channel.
 */
export function runSignAddon({ channel, amoMetadataFile = null }) {
  const cliArgs = new Set(process.argv.slice(2))
  const dryRun = cliArgs.has('--dry-run')
  const noSource = cliArgs.has('--no-source')
  const skipMetadata = cliArgs.has('--skip-metadata')

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

  const npmScript = channel === 'listed' ? 'sign:listed' : 'sign:unlisted'

  if (!dryRun && (!apiKey || !apiSecret)) {
    console.error(
      [
        'Error: Missing Mozilla Add-ons (AMO) JWT credentials.',
        '',
        '1. Generate API credentials at:',
        '   https://addons.mozilla.org/developers/addon/api/key/',
        '',
        '2. Provide credentials via environment variables:',
        `   WEB_EXT_API_KEY=user:12345678:901 WEB_EXT_API_SECRET=your-secret npm run ${npmScript}`,
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
    `--channel=${channel}`,
    '-s',
    './dist',
    '-a',
    './web-ext-artifacts',
  ]

  if (channel === 'listed' && amoMetadataFile && !skipMetadata) {
    const metadataPath = path.join(rootDir, amoMetadataFile)
    if (!existsSync(metadataPath)) {
      console.error(`Error: Missing AMO metadata file at ${metadataPath}`)
      process.exit(1)
    }
    signArgs.push('--amo-metadata', metadataPath)
  }

  if (sourceZipPath) {
    signArgs.push('--upload-source-code', sourceZipPath)
  }

  if (dryRun) {
    console.log(
      `[dry-run] Would run: npx ${signArgs.join(' ')} (using WEB_EXT_API_KEY / WEB_EXT_API_SECRET env vars)`
    )
    process.exit(0)
  }

  const signEnv = {
    ...process.env,
    NODE_OPTIONS: buildSignNodeOptions(),
    WEB_EXT_API_KEY: apiKey,
    WEB_EXT_API_SECRET: apiSecret,
  }

  runCommand('npx', signArgs, signEnv)

  const xpiFiles = existsSync(artifactsDir)
    ? readdirSync(artifactsDir)
        .filter(name => name.endsWith('.xpi'))
        .map(name => path.join(artifactsDir, name))
    : []

  console.log(`\nAMO ${channel} submission succeeded!`)
  if (xpiFiles.length > 0) {
    console.log('Signed .xpi artifact(s):')
    for (const xpi of xpiFiles) {
      console.log(`  - ${xpi}`)
    }
  }
}

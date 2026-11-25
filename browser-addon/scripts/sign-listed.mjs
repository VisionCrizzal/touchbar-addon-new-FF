import { runSignAddon } from './lib/sign-addon.mjs'

runSignAddon({
  channel: 'listed',
  amoMetadataFile: 'amo-metadata.json',
})

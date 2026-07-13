import { readFile } from 'node:fs/promises';

const configUrl = new URL('./backend_openapi_contract.json', import.meta.url);
const config = JSON.parse(await readFile(configUrl, 'utf8'));
const sourceArgumentIndex = process.argv.indexOf('--source');

let source;
let sourceLabel;
if (sourceArgumentIndex >= 0) {
  const path = process.argv[sourceArgumentIndex + 1];
  if (!path) throw new Error('--source requires a file path');
  source = await readFile(path, 'utf8');
  sourceLabel = path;
} else {
  const ref = process.env.FIESTAAA_BACKEND_REF || config.ref;
  const url = `https://raw.githubusercontent.com/${config.repository}/${ref}/${config.sourcePath}`;
  const response = await fetch(url, {
    headers: { 'User-Agent': 'fiestaaa-front-contract-check' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    throw new Error(`Unable to download backend contract source: HTTP ${response.status}`);
  }
  source = await response.text();
  sourceLabel = url;
}

const match = source.match(/sha256_hex\(&document\),\s*"([a-f0-9]{64})"/s);
if (!match) {
  throw new Error(`OpenAPI snapshot hash not found in ${sourceLabel}`);
}

const actual = match[1];
if (actual !== config.snapshotSha256) {
  throw new Error(
    `Backend OpenAPI contract changed (${actual}). Review the backend diff, update frontend models and API clients, then update tool/backend_openapi_contract.json.`,
  );
}

console.log(`Backend OpenAPI contract is compatible (${actual}).`);

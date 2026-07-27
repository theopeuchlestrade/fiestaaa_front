import { readFile } from 'node:fs/promises';

const configUrl = new URL('./backend_openapi_contract.json', import.meta.url);
const config = JSON.parse(await readFile(configUrl, 'utf8'));
const sourceArgumentIndex = process.argv.indexOf('--source');

let sourceDocument;
let sourceLabel;
if (sourceArgumentIndex >= 0) {
  const path = process.argv[sourceArgumentIndex + 1];
  if (!path) throw new Error('--source requires a file path');
  sourceDocument = JSON.parse(await readFile(path, 'utf8'));
  sourceLabel = path;
} else {
  const ref = process.env.FIESTAAA_BACKEND_REF || config.ref;
  const url = `https://raw.githubusercontent.com/${config.repository}/${ref}/${config.sourcePath}`;
  const response = await fetch(url, {
    headers: { 'User-Agent': 'fiestaaa-front-contract-check' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    throw new Error(`Unable to download backend OpenAPI document: HTTP ${response.status}`);
  }
  sourceDocument = await response.json();
  sourceLabel = url;
}

const acceptedUrl = new URL(config.acceptedSpecPath, configUrl);
const acceptedDocument = JSON.parse(await readFile(acceptedUrl, 'utf8'));

for (const [label, document] of [
  [sourceLabel, sourceDocument],
  [acceptedUrl.pathname, acceptedDocument],
]) {
  if (
    typeof document !== 'object' ||
    !document.openapi ||
    typeof document.paths !== 'object' ||
    typeof document.components !== 'object'
  ) {
    throw new Error(`${label} is not a complete OpenAPI document`);
  }
}

const canonical = (value) => JSON.stringify(value);
if (canonical(sourceDocument) !== canonical(acceptedDocument)) {
  const changes = [];
  const compare = (expected, actual, path) => {
    if (changes.length >= 20 || canonical(expected) === canonical(actual)) return;
    if (
      expected === null ||
      actual === null ||
      typeof expected !== 'object' ||
      typeof actual !== 'object'
    ) {
      changes.push(path);
      return;
    }
    const keys = new Set([...Object.keys(expected), ...Object.keys(actual)]);
    for (const key of [...keys].sort()) {
      if (!(key in expected) || !(key in actual)) {
        changes.push(`${path}/${key}`);
      } else {
        compare(expected[key], actual[key], `${path}/${key}`);
      }
      if (changes.length >= 20) return;
    }
  };
  compare(acceptedDocument, sourceDocument, '');
  throw new Error(
    `Backend OpenAPI contract changed in ${sourceLabel} (${changes.join(', ')}). ` +
      'Review the API diff and frontend clients, then regenerate tool/backend_openapi.json.',
  );
}

console.log(
  `Backend OpenAPI contract is compatible (${Object.keys(sourceDocument.paths).length} paths).`,
);

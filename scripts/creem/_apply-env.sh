#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ENV="${TARGET_ENV:?TARGET_ENV is required}"
SOURCE_FILE="${1:-}"
TARGET_FILE="${2:-${SCRIPT_DIR}/../../.env.docker}"

if [ -z "${SOURCE_FILE}" ] || [ ! -f "${SOURCE_FILE}" ]; then
  printf 'Usage: TARGET_ENV=<sandbox|production> %s <creem-env-fragment> [target-env-file]\n' "$0" >&2
  exit 1
fi

if [ ! -f "${TARGET_FILE}" ]; then
  printf 'Target env file not found: %s\n' "${TARGET_FILE}" >&2
  exit 1
fi

node - <<'NODE' "${SOURCE_FILE}" "${TARGET_FILE}" "${TARGET_ENV}"
const fs = require('fs');

const [sourceFile, targetFile, targetEnv] = process.argv.slice(2);

function parseEnv(content) {
  const map = new Map();
  for (const line of content.split('\n')) {
    if (!line || line.trim().startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    map.set(key, value);
  }
  return map;
}

const source = parseEnv(fs.readFileSync(sourceFile, 'utf8'));
const required = [
  'SELECT_PAYMENT_ENABLED',
  'DEFAULT_PAYMENT_PROVIDER',
  'STRIPE_ENABLED',
  'PAYPAL_ENABLED',
  'CREEM_ENABLED',
  'CREEM_ENVIRONMENT',
  'CREEM_API_KEY',
  'CREEM_SIGNING_SECRET',
  'CREEM_PRODUCT_IDS',
];

for (const key of required) {
  if (!source.has(key)) {
    throw new Error(`Missing ${key} in ${sourceFile}`);
  }
}

if (source.get('CREEM_ENVIRONMENT') !== targetEnv) {
  throw new Error(
    `Refusing to apply ${source.get('CREEM_ENVIRONMENT')} fragment with TARGET_ENV=${targetEnv}`
  );
}

const targetLines = fs.readFileSync(targetFile, 'utf8').split('\n');
const remaining = new Map(source);
const updated = targetLines.map((line) => {
  const idx = line.indexOf('=');
  if (idx === -1) return line;
  const key = line.slice(0, idx).trim();
  if (!remaining.has(key)) return line;
  const value = remaining.get(key);
  remaining.delete(key);
  return `${key}=${value}`;
});

for (const [key, value] of remaining.entries()) {
  updated.push(`${key}=${value}`);
}

fs.writeFileSync(targetFile, `${updated.join('\n').replace(/\n*$/, '\n')}`);
NODE

printf 'Applied %s Creem settings from %s into %s\n' "${TARGET_ENV}" "${SOURCE_FILE}" "${TARGET_FILE}"

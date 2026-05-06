#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/products.production.json}"
OUTPUT_FILE="${2:-${SCRIPT_DIR}/tmp/creem-production.env}"

TARGET_ENV=production "${SCRIPT_DIR}/_browser-setup.sh" "${CONFIG_FILE}" "${OUTPUT_FILE}"

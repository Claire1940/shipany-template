#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${1:-${SCRIPT_DIR}/tmp/creem-sandbox.env}"
TARGET_FILE="${2:-${SCRIPT_DIR}/../../.env.docker}"

TARGET_ENV=sandbox "${SCRIPT_DIR}/_apply-env.sh" "${SOURCE_FILE}" "${TARGET_FILE}"

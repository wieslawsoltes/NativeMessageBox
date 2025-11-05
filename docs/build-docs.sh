#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCFX_DIR="${SCRIPT_DIR}/docfx"

pushd "${SCRIPT_DIR}/.." > /dev/null

dotnet tool restore

docfx metadata "${DOCFX_DIR}/docfx.json"
docfx build "${DOCFX_DIR}/docfx.json"

popd > /dev/null

echo "Documentation generated at ${DOCFX_DIR}/_site"

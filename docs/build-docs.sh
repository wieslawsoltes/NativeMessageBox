#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCFX_DIR="${SCRIPT_DIR}/docfx"

pushd "${SCRIPT_DIR}/.." > /dev/null

dotnet tool restore

export PATH="${HOME}/.dotnet/tools:${PATH}"

dotnet tool run docfx metadata "${DOCFX_DIR}/docfx.json"
dotnet tool run docfx build "${DOCFX_DIR}/docfx.json"

popd > /dev/null

echo "Documentation generated at ${DOCFX_DIR}/_site"

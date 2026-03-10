#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"
dotnet tool restore
cd "${SCRIPT_DIR}/site"
dotnet tool run lunet --stacktrace build

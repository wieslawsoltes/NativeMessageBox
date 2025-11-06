#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_PRESET="wasm-release"
BUILD_ROOT="${REPO_ROOT}/build/wasm"
ARTIFACT_DIR="${REPO_ROOT}/artifacts/web"

EMSDK="${EMSDK:-${EMSDK_ROOT:-}}"

if [[ -z "${EMSDK}" ]]; then
    echo "Emscripten SDK (EMSDK) environment variable not set. Run 'source <emsdk>/emsdk_env.sh' first." >&2
    exit 1
fi

TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
if [[ ! -f "${TOOLCHAIN_FILE}" ]]; then
    echo "Emscripten toolchain file not found at ${TOOLCHAIN_FILE}. Verify EMSDK is correct." >&2
    exit 1
fi

if ! command -v emcc >/dev/null 2>&1; then
    echo "emcc not found on PATH. Ensure Emscripten environment is activated." >&2
    exit 1
fi

mkdir -p "${ARTIFACT_DIR}"

echo "Configuring WebAssembly build (preset: ${BUILD_PRESET})..."
cmake --preset "${BUILD_PRESET}"

echo "Building libnative_message_box.wasm..."
cmake --build --preset "${BUILD_PRESET}" --target nativemessagebox --clean-first

WASM_OUTPUT="$(find "${BUILD_ROOT}" -name 'libnative_message_box.wasm' -print -quit || true)"
if [[ -z "${WASM_OUTPUT}" ]]; then
    echo "Failed to locate libnative_message_box.wasm under ${BUILD_ROOT}" >&2
    exit 1
fi

ARTIFACT_NAME="$(basename "${WASM_OUTPUT}")"
cp "${WASM_OUTPUT}" "${ARTIFACT_DIR}/${ARTIFACT_NAME}"

JS_SHIM="$(find "${BUILD_ROOT}" -name 'libnative_message_box.js' -print -quit || true)"
if [[ -n "${JS_SHIM}" ]]; then
    cp "${JS_SHIM}" "${ARTIFACT_DIR}/"
fi

MAP_FILE="$(find "${BUILD_ROOT}" -name 'libnative_message_box.wasm.map' -print -quit || true)"
if [[ -n "${MAP_FILE}" ]]; then
    cp "${MAP_FILE}" "${ARTIFACT_DIR}/"
fi

EMCC_VERSION="$(emcc --version 2>/dev/null | head -n 1 | tr -d '\r' || echo "unknown")"
GENERATED_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VERSION="$(git -C "${REPO_ROOT}" describe --tags --always 2>/dev/null || echo "0.0.0")"

cat > "${ARTIFACT_DIR}/manifest.json" <<JSON
{
  "artifact": "${ARTIFACT_NAME}",
  "version": "${VERSION}",
  "generated": "${GENERATED_TS}",
  "toolchain": "${EMCC_VERSION}",
  "notes": "Generated via CMake preset '${BUILD_PRESET}'"
}
JSON

echo "WebAssembly artifacts available under ${ARTIFACT_DIR}"

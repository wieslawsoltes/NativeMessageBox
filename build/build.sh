#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG="${1:-Release}"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
NATIVE_BUILD_DIR="${ROOT_DIR}/build/native"

mkdir -p "${ARTIFACTS_DIR}/nuget" "${ARTIFACTS_DIR}/native"

cmake -S "${ROOT_DIR}" -B "${NATIVE_BUILD_DIR}" -G Ninja -DCMAKE_BUILD_TYPE="${CONFIG}"
cmake --build "${NATIVE_BUILD_DIR}" --config "${CONFIG}"
ctest --test-dir "${NATIVE_BUILD_DIR}" --output-on-failure

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

case "${ARCH_NAME}" in
  x86_64|amd64)
    ARCH_RID="x64"
    ;;
  arm64|aarch64)
    ARCH_RID="arm64"
    ;;
  *)
    ARCH_RID="${ARCH_NAME}"
    ;;
esac

case "${OS_NAME}" in
  Darwin)
    RID="osx-${ARCH_RID}"
    LIB_PATTERN="libnativemessagebox.dylib"
    ;;
  Linux)
    RID="linux-${ARCH_RID}"
    LIB_PATTERN="libnativemessagebox.so"
    ;;
  MINGW*|MSYS*)
    RID="win-${ARCH_RID}"
    LIB_PATTERN="nativemessagebox.dll"
    ;;
  *)
    RID="unknown-${ARCH_RID}"
    LIB_PATTERN="libnativemessagebox.*"
    ;;
esac

LIB_PATH="$(find "${NATIVE_BUILD_DIR}" -type f -name "${LIB_PATTERN}" | head -n 1 || true)"
declare -a SYMBOL_FILES=()
if [[ -n "${LIB_PATH}" ]]; then
  DEST_DIR="${ARTIFACTS_DIR}/native/${RID}"
  mkdir -p "${DEST_DIR}"
  cp "${LIB_PATH}" "${DEST_DIR}/"

  case "${OS_NAME}" in
    Darwin)
      if [[ -d "${LIB_PATH}.dSYM" ]]; then
        rsync -a "${LIB_PATH}.dSYM" "${DEST_DIR}/"
        SYMBOL_FILES+=("$(basename "${LIB_PATH}.dSYM")")
      fi
      ;;
    Linux)
      DEBUG_PATH="${LIB_PATH}.debug"
      if [[ -f "${DEBUG_PATH}" ]]; then
        cp "${DEBUG_PATH}" "${DEST_DIR}/"
        SYMBOL_FILES+=("$(basename "${DEBUG_PATH}")")
      fi
      ;;
  esac

  if (( ${#SYMBOL_FILES[@]} )); then
    SYMBOL_JSON=$(printf '"%s",' "${SYMBOL_FILES[@]}" | sed 's/,$//')
  else
    SYMBOL_JSON=""
  fi

  VERSION=$(git -C "${ROOT_DIR}" describe --tags --always 2>/dev/null || echo "0.0.0")
  cat > "${DEST_DIR}/manifest.json" <<MANIFEST
{
  "rid": "${RID}",
  "library": "$(basename "${LIB_PATH}")",
  "symbols": [${SYMBOL_JSON}],
  "version": "${VERSION}",
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
MANIFEST

  RUNTIME_DIR="${ROOT_DIR}/src/dotnet/NativeMessageBox/runtimes/${RID}/native"
  mkdir -p "${RUNTIME_DIR}"
  cp "${LIB_PATH}" "${RUNTIME_DIR}/"
  if (( ${#SYMBOL_FILES[@]} )); then
    for symbol in "${SYMBOL_FILES[@]}"; do
      cp "${DEST_DIR}/${symbol}" "${RUNTIME_DIR}/" 2>/dev/null || true
    done
  fi

  (cd "${ARTIFACTS_DIR}/native" && zip -q -r "../native-${RID}.zip" "${RID}")
fi

pushd "${ROOT_DIR}" > /dev/null

dotnet restore NativeMessageBox.sln
dotnet build NativeMessageBox.sln --configuration "${CONFIG}" --no-restore
dotnet pack src/dotnet/NativeMessageBox/NativeMessageBox.csproj --configuration "${CONFIG}" --no-build --output "${ARTIFACTS_DIR}/nuget"

popd > /dev/null

echo "Artifacts available under ${ARTIFACTS_DIR}"

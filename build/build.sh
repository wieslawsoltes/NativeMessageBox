#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: build.sh [options]

Options:
  <Configuration>           Optional positional build configuration (e.g. Release)
  --config <Configuration>   Build configuration (default: Release)
  --targets <list>           Comma separated list of targets: host,ios,android,wasm
  --host                     Include the host-native build (default when no targets specified)
  --ios                      Include the iOS xcframework build (macOS only)
  --android                  Include the Android AAR build
  --wasm                     Include the WebAssembly build
  --all                      Build all available targets
  --skip-tests               Skip running native ctest suites for the host build
  --skip-dotnet              Skip dotnet restore/build/pack for the host build
  -h, --help                 Show this help and exit

Examples:
  ./build.sh                         # Host build only (Release)
  ./build.sh --config Debug --android
  ./build.sh --all --skip-tests
HELP
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
NATIVE_BUILD_DIR="${ROOT_DIR}/build/native"

CONFIG="Release"
CONFIG_SET=false
RUN_TESTS=true
RUN_DOTNET=true
declare -a REQUESTED_TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config|-c)
      shift
      CONFIG="${1:-}"
      if [[ -z "${CONFIG}" ]]; then
        echo "Missing value for --config" >&2
        exit 1
      fi
      CONFIG_SET=true
      ;;
    --targets|-t)
      shift
      IFS=',' read -r -a REQUESTED_TARGETS <<< "${1:-}"
      ;;
    --host)
      REQUESTED_TARGETS+=("host")
      ;;
    --ios)
      REQUESTED_TARGETS+=("ios")
      ;;
    --android)
      REQUESTED_TARGETS+=("android")
      ;;
    --wasm)
      REQUESTED_TARGETS+=("wasm")
      ;;
    --all)
      REQUESTED_TARGETS=("host" "ios" "android" "wasm")
      ;;
    --skip-tests)
      RUN_TESTS=false
      ;;
    --skip-dotnet)
      RUN_DOTNET=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "${1}" != -* && "${CONFIG_SET}" == "false" ]]; then
        CONFIG="$1"
        CONFIG_SET=true
      else
        echo "Unknown option: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift || true
done

declare -A TARGETS=()
if (( ${#REQUESTED_TARGETS[@]} == 0 )); then
  TARGETS["host"]=1
else
  for target in "${REQUESTED_TARGETS[@]}"; do
    case "${target}" in
      host|ios|android|wasm)
        TARGETS["${target}"]=1
        ;;
      "" )
        ;;
      *)
        echo "Unsupported target '${target}'. Allowed values: host, ios, android, wasm." >&2
        exit 1
        ;;
    esac
  done
fi

mkdir -p "${ARTIFACTS_DIR}"

build_host() {
  mkdir -p "${ARTIFACTS_DIR}/nuget" "${ARTIFACTS_DIR}/native"

  cmake -S "${ROOT_DIR}" -B "${NATIVE_BUILD_DIR}" -G Ninja -DCMAKE_BUILD_TYPE="${CONFIG}"
  cmake --build "${NATIVE_BUILD_DIR}" --config "${CONFIG}"

  if [[ "${RUN_TESTS}" == "true" ]]; then
    ctest --test-dir "${NATIVE_BUILD_DIR}" --output-on-failure
  else
    echo "Skipping native tests"
  fi

  OS_NAME="$(uname -s)"
  ARCH_NAME="$(uname -m)"

  case "${ARCH_NAME}" in
    x86_64|amd64) ARCH_RID="x64" ;;
    arm64|aarch64) ARCH_RID="arm64" ;;
    *) ARCH_RID="${ARCH_NAME}" ;;
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
  else
    echo "Unable to locate built native library matching '${LIB_PATTERN}'."
  fi

  if [[ "${RUN_DOTNET}" == "true" ]]; then
    pushd "${ROOT_DIR}" > /dev/null
    dotnet restore NativeMessageBox.sln
    dotnet build NativeMessageBox.sln --configuration "${CONFIG}" --no-restore
    dotnet pack src/dotnet/NativeMessageBox/NativeMessageBox.csproj --configuration "${CONFIG}" --no-build --output "${ARTIFACTS_DIR}/nuget"
    popd > /dev/null
  else
    echo "Skipping dotnet restore/build/pack"
  fi
}

package_android() {
  echo "Packaging Android AAR"
  "${SCRIPT_DIR}/scripts/package-android-aar.sh"
}

package_wasm() {
  echo "Packaging WebAssembly module"
  "${SCRIPT_DIR}/scripts/package-wasm.sh"
}

package_ios() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping iOS build: requires macOS host" >&2
    return 0
  fi

  echo "Packaging iOS xcframework (${CONFIG})"
  CONFIGURATION="${CONFIG}" "${SCRIPT_DIR}/scripts/package-ios-xcframework.sh"
}

if [[ -n "${TARGETS[host]+set}" ]]; then
  build_host
fi

if [[ -n "${TARGETS[android]+set}" ]]; then
  package_android
fi

if [[ -n "${TARGETS[wasm]+set}" ]]; then
  package_wasm
fi

if [[ -n "${TARGETS[ios]+set}" ]]; then
  package_ios
fi

echo "Artifacts available under ${ARTIFACTS_DIR}"

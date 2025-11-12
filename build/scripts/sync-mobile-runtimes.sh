#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: sync-mobile-runtimes.sh [--android <dir>] [--ios <dir>] [--web <dir>] [--dest <dir>]

Copies Android, iOS, and browser (WebAssembly) artifacts into
src/dotnet/NativeMessageBox/runtimes so they are included in the NuGet package.

Arguments:
  --android PATH   Directory containing the extracted Android artifacts (jni/<abi>/...).
  --ios PATH       Directory containing the NativeMessageBox.xcframework output.
  --web PATH       Directory containing libnative_message_box.wasm (+ optional js/map).
  --dest PATH      Optional destination root (defaults to src/dotnet/NativeMessageBox/runtimes).
  -h, --help       Show this help message.
HELP
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync-native-runtime.sh"
DEST_ROOT="${ROOT_DIR}/src/dotnet/NativeMessageBox/runtimes"

ANDROID_SOURCE=""
IOS_SOURCE=""
WEB_SOURCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android)
      ANDROID_SOURCE="${2:-}"
      shift 2
      ;;
    --ios)
      IOS_SOURCE="${2:-}"
      shift 2
      ;;
    --web)
      WEB_SOURCE="${2:-}"
      shift 2
      ;;
    --dest)
      DEST_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -x "${SYNC_SCRIPT}" ]]; then
  echo "Required helper script not found: ${SYNC_SCRIPT}" >&2
  exit 1
fi

to_abs() {
  local input="${1:-}"
  if [[ -z "${input}" ]]; then
    echo ""
    return
  fi
  if [[ "${input}" == /* ]]; then
    echo "${input}"
  else
    echo "${ROOT_DIR}/${input}"
  fi
}

normalize_ios_arch() {
  case "$1" in
    arm64) echo "arm64" ;;
    armv7|arm) echo "arm" ;;
    x86_64) echo "x64" ;;
    x86) echo "x86" ;;
    *)
      echo ""
      ;;
  esac
}

sync_android() {
  local source_dir
  source_dir="$(to_abs "${1}")"
  if [[ -z "${source_dir}" || ! -d "${source_dir}" ]]; then
    return
  fi

  local jni_dir="${source_dir}/jni"
  if [[ ! -d "${jni_dir}" ]]; then
    echo "Android artifacts missing expected jni/ layout under ${source_dir}; skipping." >&2
    return
  fi

  shopt -s nullglob
  for abi_dir in "${jni_dir}"/*; do
    [[ -d "${abi_dir}" ]] || continue
    local abi
    abi="$(basename "${abi_dir}")"
    local rid=""
    case "${abi}" in
      arm64-v8a) rid="android-arm64" ;;
      armeabi-v7a) rid="android-arm" ;;
      x86_64) rid="android-x64" ;;
      x86) rid="android-x86" ;;
      *)
        echo "Skipping unsupported Android ABI '${abi}'." >&2
        continue
        ;;
    esac
    "${SYNC_SCRIPT}" --source "${abi_dir}" --rid "${rid}" --library "libnativemessagebox.so"
  done
  shopt -u nullglob
}

sync_ios() {
  local source_dir
  source_dir="$(to_abs "${1}")"
  if [[ -z "${source_dir}" || ! -d "${source_dir}" ]]; then
    return
  fi

  local framework_dir="${source_dir}"
  if [[ ! -f "${framework_dir}/Info.plist" ]]; then
    if [[ -d "${framework_dir}/NativeMessageBox.xcframework" ]]; then
      framework_dir="${framework_dir}/NativeMessageBox.xcframework"
    else
      local candidate
      candidate="$(find "${framework_dir}" -maxdepth 1 -type d -name '*.xcframework' -print -quit || true)"
      if [[ -n "${candidate}" ]]; then
        framework_dir="${candidate}"
      fi
    fi
  fi

  if [[ ! -f "${framework_dir}/Info.plist" ]]; then
    echo "Unable to locate NativeMessageBox.xcframework under ${source_dir}; skipping." >&2
    return
  fi

  local info_plist="${framework_dir}/Info.plist"
  local python_output=""
  if ! python_output="$(python3 - "${info_plist}" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open('rb') as f:
    data = plistlib.load(f)

for lib in data.get('AvailableLibraries', []):
    identifier = lib.get('LibraryIdentifier')
    platform = lib.get('SupportedPlatform')
    variant = (lib.get('SupportedPlatformVariant') or '').lower()
    archs = lib.get('SupportedArchitectures', [])

    if not identifier or not platform:
        continue

    prefix = platform.lower()
    if prefix == 'ios' and variant == 'simulator':
        prefix = 'iossimulator'
    elif prefix == 'ios' and variant == 'maccatalyst':
        prefix = 'maccatalyst'
    elif prefix == 'tvos' and variant == 'simulator':
        prefix = 'tvossimulator'

    arch_list = ",".join(archs)
    print(f"{identifier}|{prefix}|{arch_list}")
PY
  )"; then
    echo "Failed to parse ${info_plist}; skipping iOS runtime sync." >&2
    return
  fi

  local entries=()
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    entries+=("${line}")
  done <<< "${python_output}"

  if (( ${#entries[@]} == 0 )); then
    echo "No entries found in ${info_plist}; skipping iOS runtime sync." >&2
    return
  fi

  local -a synced_prefixes=()
  for entry in "${entries[@]}"; do
    [[ -z "${entry}" ]] && continue
    IFS='|' read -r identifier prefix arch_list <<< "${entry}"
    [[ -z "${identifier}" || -z "${prefix}" ]] && continue

    local variant_dir="${framework_dir}/${identifier}"
    if [[ ! -d "${variant_dir}" ]]; then
      echo "Warning: Missing xcframework slice directory ${identifier}" >&2
      continue
    fi

    local lib_path
    lib_path="$(find "${variant_dir}" -maxdepth 1 -name 'libnativemessagebox.dylib' -print -quit || true)"
    [[ -n "${lib_path}" ]] || continue

    local -a normalized_arches=()
    IFS=',' read -r -a archs <<< "${arch_list}"
    for arch in "${archs[@]}"; do
      arch="${arch//[[:space:]]/}"
      [[ -z "${arch}" ]] && continue
      local norm
      norm="$(normalize_ios_arch "${arch}")"
      if [[ -z "${norm}" ]]; then
        echo "Warning: unsupported iOS architecture '${arch}' in ${identifier}; skipping." >&2
        continue
      fi
      normalized_arches+=("${norm}")
      local rid="${prefix}-${norm}"
      "${SYNC_SCRIPT}" --source "${variant_dir}" --rid "${rid}" --library "libnativemessagebox.dylib"
    done

    if (( ${#normalized_arches[@]} )); then
      local base="${prefix}"
      local already_synced=false
      for existing in ${synced_prefixes[@]+"${synced_prefixes[@]}"}; do
        if [[ "${existing}" == "${base}" ]]; then
          already_synced=true
          break
        fi
      done
      if [[ "${already_synced}" == false && -n "${base}" ]]; then
        "${SYNC_SCRIPT}" --source "${variant_dir}" --rid "${base}" --library "libnativemessagebox.dylib"
        synced_prefixes+=("${base}")
      fi
    fi
  done
}

sync_web() {
  local source_dir
  source_dir="$(to_abs "${1}")"
  if [[ -z "${source_dir}" || ! -d "${source_dir}" ]]; then
    return
  fi

  local dest="${DEST_ROOT}/browser-wasm/native"
  rm -rf "${dest}"
  mkdir -p "${dest}"

  local copied=false
  for file in libnative_message_box.wasm libnative_message_box.js libnative_message_box.wasm.map; do
    if [[ -f "${source_dir}/${file}" ]]; then
      cp "${source_dir}/${file}" "${dest}/"
      copied=true
    fi
  done

  if [[ "${copied}" == false ]]; then
    echo "No WebAssembly artifacts found under ${source_dir}; directory left empty." >&2
  fi
}

sync_android "${ANDROID_SOURCE}"
sync_ios "${IOS_SOURCE}"
sync_web "${WEB_SOURCE}"

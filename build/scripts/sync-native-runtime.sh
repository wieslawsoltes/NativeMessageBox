#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: sync-native-runtime.sh --source <path> --rid <rid> [--library <filename>]

Copies a native artifact produced on another platform into the local
src/dotnet/NativeMessageBox/runtimes/<rid>/native folder so dotnet pack
includes it.

Arguments:
  --source PATH     File or directory that contains the native library. If the
                    path points to a .zip file it will be extracted automatically.
  --rid RID         Runtime identifier (e.g. linux-x64, osx-arm64, win-x64).
  --library NAME    Optional explicit library filename override.
  -h, --help        Show this help.
HELP
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SOURCE=""
RID=""
LIBRARY_OVERRIDE=""
declare -a CLEANUP_DIRS=()

cleanup() {
  if (( ${#CLEANUP_DIRS[@]} == 0 )); then
    return 0
  fi

  for dir in "${CLEANUP_DIRS[@]}"; do
    [[ -n "${dir}" ]] && rm -rf "${dir}"
  done

  return 0
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --rid)
      RID="${2:-}"
      shift 2
      ;;
    --library)
      LIBRARY_OVERRIDE="${2:-}"
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

if [[ -z "${SOURCE}" ]]; then
  echo "--source is required" >&2
  usage
  exit 1
fi

if [[ -z "${RID}" ]]; then
  echo "--rid is required" >&2
  usage
  exit 1
fi

expand_source() {
  local path="$1"
  if [[ -f "${path}" && "${path}" == *.zip ]]; then
    local tmp
    tmp="$(mktemp -d)"
    unzip -q "${path}" -d "${tmp}"
    CLEANUP_DIRS+=("${tmp}")
    echo "${tmp}"
    return 0
  fi

  if [[ -d "${path}" ]]; then
    shopt -s nullglob
    local zips=("${path}"/*.zip)
    shopt -u nullglob
    if (( ${#zips[@]} )); then
      local tmp
      tmp="$(mktemp -d)"
      CLEANUP_DIRS+=("${tmp}")
      for zip_file in "${zips[@]}"; do
        unzip -q "${zip_file}" -d "${tmp}"
      done
      echo "${tmp}"
      return 0
    fi
    echo "${path}"
    return 0
  fi

  echo ""
  return 1
}

SOURCE="$(expand_source "${SOURCE}")"
if [[ -z "${SOURCE}" ]]; then
  echo "Source path is invalid or could not be expanded" >&2
  exit 1
fi

if [[ -n "${LIBRARY_OVERRIDE}" ]]; then
  LIB_NAME="${LIBRARY_OVERRIDE}"
else
  case "${RID%%-*}" in
    linux) LIB_NAME="libnativemessagebox.so" ;;
    osx) LIB_NAME="libnativemessagebox.dylib" ;;
    win) LIB_NAME="nativemessagebox.dll" ;;
    *)
      echo "Unable to determine default library name for RID '${RID}'" >&2
      exit 1
      ;;
  esac
fi

find_first() {
  local pattern="$1"
  find "${SOURCE}" -type f -iname "${pattern}" -print -quit 2>/dev/null || true
}

find_dir() {
  local pattern="$1"
  find "${SOURCE}" -type d -iname "${pattern}" -print -quit 2>/dev/null || true
}

LIB_PATH="$(find_first "${LIB_NAME}")"
if [[ -z "${LIB_PATH}" ]]; then
  echo "Failed to locate ${LIB_NAME} for RID '${RID}' under '${SOURCE}'" >&2
  exit 1
fi

DEST_DIR="${ROOT_DIR}/src/dotnet/NativeMessageBox/runtimes/${RID}/native"
rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"
cp "${LIB_PATH}" "${DEST_DIR}/"

case "${RID%%-*}" in
  win)
    PDB_NAME="${LIB_NAME%.*}.pdb"
    PDB_PATH="$(find_first "${PDB_NAME}")"
    if [[ -n "${PDB_PATH}" ]]; then
      cp "${PDB_PATH}" "${DEST_DIR}/"
    fi
    ;;
  linux)
    DEBUG_NAME="${LIB_NAME}.debug"
    DEBUG_PATH="$(find_first "${DEBUG_NAME}")"
    if [[ -n "${DEBUG_PATH}" ]]; then
      cp "${DEBUG_PATH}" "${DEST_DIR}/"
    fi
    ;;
  osx)
    DSYM_NAME="${LIB_NAME}.dSYM"
    DSYM_DIR="$(find_dir "${DSYM_NAME}")"
    if [[ -n "${DSYM_DIR}" ]]; then
      rsync -a "${DSYM_DIR}" "${DEST_DIR}/"
    fi
    ;;
esac

echo "Synchronized ${RID} runtime from '${SOURCE}' into '${DEST_DIR}'"

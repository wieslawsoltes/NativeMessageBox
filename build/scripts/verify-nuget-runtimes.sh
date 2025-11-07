#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: verify-nuget-runtimes.sh --package <path> [--rids rid1,rid2,...]

Ensures that the provided NativeMessageBox NuGet package contains native
libraries for every expected RID under runtimes/<rid>/native.

Arguments:
  --package PATH    Path to the .nupkg file to inspect.
  --rids LIST       Optional comma separated list of required runtime identifiers.
                    Defaults to linux-x64,osx-arm64,win-x64.
  -h, --help        Show this help.
HELP
}

PACKAGE=""
RID_INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package|-p)
      PACKAGE="${2:-}"
      shift 2
      ;;
    --rids)
      RID_INPUT="${2:-}"
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

if [[ -z "${PACKAGE}" ]]; then
  echo "--package is required" >&2
  usage
  exit 1
fi

if [[ ! -f "${PACKAGE}" ]]; then
  echo "Package '${PACKAGE}' not found" >&2
  exit 1
fi

IFS=',' read -r -a EXPECTED_RIDS <<< "${RID_INPUT}"
if (( ${#EXPECTED_RIDS[@]} == 0 )); then
  EXPECTED_RIDS=("linux-x64" "osx-arm64" "win-x64")
fi

lib_name_for_rid() {
  case "${1%%-*}" in
    linux) echo "libnativemessagebox.so" ;;
    osx) echo "libnativemessagebox.dylib" ;;
    win) echo "nativemessagebox.dll" ;;
    *)
      echo ""
      ;;
  esac
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

unzip -q "${PACKAGE}" -d "${WORK_DIR}"

missing=0
for rid in "${EXPECTED_RIDS[@]}"; do
  lib_name="$(lib_name_for_rid "${rid}")"
  if [[ -z "${lib_name}" ]]; then
    echo "Skipping unknown RID '${rid}'" >&2
    continue
  fi
  target="${WORK_DIR}/runtimes/${rid}/native/${lib_name}"
  if [[ ! -f "${target}" ]]; then
    echo "Missing ${lib_name} for RID '${rid}' in package '${PACKAGE}'" >&2
    missing=1
  fi
done

if (( missing )); then
  exit 1
fi

echo "Verified native runtimes (${EXPECTED_RIDS[*]}) in ${PACKAGE}"

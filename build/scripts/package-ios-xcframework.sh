#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_ROOT="${REPO_ROOT}/build/ios"
ARTIFACT_DIR="${REPO_ROOT}/artifacts/ios"
XCFRAMEWORK_NAME="NativeMessageBox.xcframework"
CONFIGURATION="${CONFIGURATION:-Release}"
DEPLOYMENT_TARGET="${NMB_IOS_DEPLOYMENT_TARGET:-13.0}"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild is required to create an xcframework. Install Xcode command-line tools via 'xcode-select --install'." >&2
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
    echo "cmake is required to configure the iOS build." >&2
    exit 1
fi

function configure_and_build()
{
    local variant="$1"
    local sysroot="$2"
    local architectures="$3"

    local build_dir="${BUILD_ROOT}/${variant}"
    cmake -S "${REPO_ROOT}" \
          -B "${build_dir}" \
          -G Xcode \
          -DCMAKE_SYSTEM_NAME=iOS \
          -DCMAKE_OSX_SYSROOT="${sysroot}" \
          -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
          -DCMAKE_OSX_ARCHITECTURES="${architectures}" \
          -DBUILD_SHARED_LIBS=ON \
          -DBUILD_TESTING=OFF

    cmake --build "${build_dir}" \
          --config "${CONFIGURATION}" \
          --target nativemessagebox \
          -- \
          CODE_SIGNING_ALLOWED=NO \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_IDENTITY=
}

function resolve_library_path()
{
    local variant="$1"
    local sysroot_dir="$2"
    local build_dir="${BUILD_ROOT}/${variant}"
    local lib_path

    lib_path="$(find "${build_dir}" -path "*${sysroot_dir}/libnativemessagebox.dylib" -print -quit || true)"
    if [[ -z "${lib_path}" ]]; then
        echo "Unable to locate build output for ${variant} (${sysroot_dir})." >&2
        exit 1
    fi

    echo "${lib_path}"
}

echo "Creating iOS xcframework (${CONFIGURATION})"
rm -rf "${BUILD_ROOT}" "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}"

configure_and_build "device" "iphoneos" "arm64"
configure_and_build "simulator" "iphonesimulator" "arm64;x86_64"

DEVICE_LIB="$(resolve_library_path "device" "Release-iphoneos")"
SIM_LIB="$(resolve_library_path "simulator" "Release-iphonesimulator")"

HEADERS_DIR="${REPO_ROOT}/include"
OUTPUT_PATH="${ARTIFACT_DIR}/${XCFRAMEWORK_NAME}"

xcodebuild -create-xcframework \
    -library "${DEVICE_LIB}" -headers "${HEADERS_DIR}" \
    -library "${SIM_LIB}" -headers "${HEADERS_DIR}" \
    -output "${OUTPUT_PATH}"

cat > "${ARTIFACT_DIR}/manifest.json" <<MANIFEST
{
  "name": "${XCFRAMEWORK_NAME}",
  "configuration": "${CONFIGURATION}",
  "deploymentTarget": "${DEPLOYMENT_TARGET}",
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": [
    {
      "variant": "device",
      "sysroot": "iphoneos",
      "architectures": ["arm64"],
      "library": "$(basename "${DEVICE_LIB}")"
    },
    {
      "variant": "simulator",
      "sysroot": "iphonesimulator",
      "architectures": ["arm64", "x86_64"],
      "library": "$(basename "${SIM_LIB}")"
    }
  ]
}
MANIFEST

echo "XCFramework created at ${OUTPUT_PATH}"

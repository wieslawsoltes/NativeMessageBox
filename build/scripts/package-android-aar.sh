#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_ROOT="${REPO_ROOT}/build/android"
ARTIFACT_DIR="${REPO_ROOT}/artifacts/android"
AAR_NAME="NativeMessageBox.aar"

ANDROID_ABIS=${ANDROID_ABIS:-"arm64-v8a armeabi-v7a x86_64"}
ANDROID_API_LEVEL=${ANDROID_API_LEVEL:-21}
ANDROID_TARGET_SDK=${ANDROID_TARGET_SDK:-34}

ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -z "${ANDROID_NDK_ROOT}" || ! -d "${ANDROID_NDK_ROOT}" ]]; then
    echo "Android NDK not found. Set ANDROID_NDK_ROOT (or ANDROID_NDK_HOME)." >&2
    exit 1
fi

if [[ -z "${ANDROID_SDK_ROOT}" || ! -d "${ANDROID_SDK_ROOT}" ]]; then
    echo "Android SDK not found. Set ANDROID_SDK_ROOT (or ANDROID_HOME)." >&2
    exit 1
fi

ANDROID_JAR=""
if [[ -f "${ANDROID_SDK_ROOT}/platforms/android-${ANDROID_TARGET_SDK}/android.jar" ]]; then
    ANDROID_JAR="${ANDROID_SDK_ROOT}/platforms/android-${ANDROID_TARGET_SDK}/android.jar"
else
    latest_platform=$(ls "${ANDROID_SDK_ROOT}/platforms" 2>/dev/null | grep -E '^android-[0-9]+' | sort -V | tail -n 1 || true)
    if [[ -n "${latest_platform}" && -f "${ANDROID_SDK_ROOT}/platforms/${latest_platform}/android.jar" ]]; then
        ANDROID_JAR="${ANDROID_SDK_ROOT}/platforms/${latest_platform}/android.jar"
    fi
fi

if [[ -z "${ANDROID_JAR}" ]]; then
    echo "Unable to locate android.jar within the SDK. Install the platform tools matching ANDROID_TARGET_SDK or newer." >&2
    exit 1
fi

JAVA_SRC_DIR="${REPO_ROOT}/src/native/android/java"
if [[ ! -d "${JAVA_SRC_DIR}" ]]; then
    echo "Java bridge sources not found at ${JAVA_SRC_DIR}." >&2
    exit 1
fi

CMAKE_TOOLCHAIN="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"
if [[ ! -f "${CMAKE_TOOLCHAIN}" ]]; then
    echo "Unable to find android.toolchain.cmake at ${CMAKE_TOOLCHAIN}." >&2
    exit 1
fi

mkdir -p "${BUILD_ROOT}" "${ARTIFACT_DIR}"
rm -rf "${BUILD_ROOT:?}/"* "${ARTIFACT_DIR:?}/"*

build_abi() {
    local abi="$1"
    local build_dir="${BUILD_ROOT}/${abi}"

    echo "Configuring ${abi}..."
    cmake -S "${REPO_ROOT}" \
          -B "${build_dir}" \
          -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN}" \
          -DANDROID_ABI="${abi}" \
          -DANDROID_PLATFORM="android-${ANDROID_API_LEVEL}" \
          -DBUILD_SHARED_LIBS=ON \
          -DBUILD_TESTING=OFF \
          -DANDROID_STL=c++_static

    echo "Building ${abi}..."
    cmake --build "${build_dir}" --target nativemessagebox

    local output
    output="$(find "${build_dir}" -name "libnativemessagebox.so" -print -quit || true)"
    if [[ -z "${output}" ]]; then
        echo "Failed to locate libnativemessagebox.so for ${abi}" >&2
        exit 1
    fi

    local dest="${BUILD_ROOT}/aar/jni/${abi}"
    mkdir -p "${dest}"
    cp "${output}" "${dest}/"
    mkdir -p "${ARTIFACT_DIR}/jni/${abi}"
    cp "${output}" "${ARTIFACT_DIR}/jni/${abi}/"
}

for abi in ${ANDROID_ABIS}; do
    build_abi "${abi}"
done

CLASSES_DIR="${BUILD_ROOT}/classes"
mkdir -p "${CLASSES_DIR}"

JAVA_SOURCES=()
while IFS= read -r -d '' file; do
    JAVA_SOURCES+=("$file")
done < <(find "${JAVA_SRC_DIR}" -name "*.java" -print0)

if [[ ${#JAVA_SOURCES[@]} -eq 0 ]]; then
    echo "No Java sources found under ${JAVA_SRC_DIR}." >&2
    exit 1
fi

echo "Compiling Java bridge..."
javac -source 1.8 -target 1.8 -encoding UTF-8 \
      -bootclasspath "${ANDROID_JAR}" \
      -classpath "${ANDROID_JAR}" \
      -d "${CLASSES_DIR}" \
      "${JAVA_SOURCES[@]}"

CLASSES_JAR="${BUILD_ROOT}/classes.jar"
jar --create --file "${CLASSES_JAR}" -C "${CLASSES_DIR}" .

AAR_DIR="${BUILD_ROOT}/aar"
mkdir -p "${AAR_DIR}"
cp "${CLASSES_JAR}" "${AAR_DIR}/classes.jar"

cat > "${AAR_DIR}/AndroidManifest.xml" <<MANIFEST
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="com.nativeinterop.nativemessagebox">
  <uses-sdk android:minSdkVersion="${ANDROID_API_LEVEL}"
            android:targetSdkVersion="${ANDROID_TARGET_SDK}" />
</manifest>
MANIFEST

pushd "${AAR_DIR}" > /dev/null
zip -r "${ARTIFACT_DIR}/${AAR_NAME}" . > /dev/null
popd > /dev/null

VERSION=$(git -C "${REPO_ROOT}" describe --tags --always 2>/dev/null || echo "0.0.0")
GENERATED_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "${ARTIFACT_DIR}/manifest.json" <<JSON
{
  "name": "${AAR_NAME}",
  "abis": [$(printf '"%s",' ${ANDROID_ABIS} | sed 's/,$//')],
  "apiLevel": ${ANDROID_API_LEVEL},
  "targetSdk": ${ANDROID_TARGET_SDK},
  "version": "${VERSION}",
  "generated": "${GENERATED_TS}"
}
JSON

echo "Android AAR created at ${ARTIFACT_DIR}/${AAR_NAME}"

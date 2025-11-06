# Android Packaging Guide

The Android build ships as an AAR that contains the JNI bridge (`NativeMessageBoxBridge`) and prebuilt `libnativemessagebox.so` binaries for common ABIs. The AAR can be referenced directly from Xamarin/.NET for Android (`<AndroidLibrary>` item) or included in Gradle builds.

## Prerequisites
- Android SDK (with the desired platform installed).
- Android NDK r23+.
- Java toolchain (`javac`, `jar`).
- CMake 3.21+ and Ninja (used by the packaging script).

Set the following environment variables (these are read by the script):

| Variable | Description | Example |
| --- | --- | --- |
| `ANDROID_NDK_ROOT` | Path to the extracted NDK | `/Users/me/Library/Android/sdk/ndk/26.1.10909125` |
| `ANDROID_SDK_ROOT` | Path to the Android SDK | `/Users/me/Library/Android/sdk` |
| `ANDROID_API_LEVEL` (optional) | Minimum API level to target (default `21`) | `23` |
| `ANDROID_TARGET_SDK` (optional) | Target SDK level for the manifest (default `34`) | `34` |
| `ANDROID_ABIS` (optional) | Space-separated list of ABIs to build (default `arm64-v8a armeabi-v7a x86_64`) | `"arm64-v8a x86_64"` |

## Generating the AAR

```bash
./build/scripts/package-android-aar.sh
```

Outputs are written to `artifacts/android/`:

- `NativeMessageBox.aar` — packaged Java bridge + native libraries.
- `jni/<abi>/libnativemessagebox.so` — extracted copies of the native binaries for convenience.
- `manifest.json` — build metadata (ABIs, API level, timestamp, git version).

The CI workflow (`android-aar` job in `.github/workflows/ci.yml`) runs this script on every push/pr so the packaged artifacts are always up to date. Robolectric-based bridge tests (`tests/android/bridge-tests`) also run in CI to exercise the `setTestCallback` hook.

The build uses `ANDROID_STL=c++_static`, so no additional STL shared libraries are required.

## Consuming the AAR in .NET for Android

To use the packaged artifacts in the cross-platform sample (or any .NET for Android project), add the generated AAR to the project file:

```xml
<ItemGroup>
  <AndroidLibrary Include="..\..\..\artifacts\android\NativeMessageBox.aar" />
</ItemGroup>
```

At runtime the managed host automatically probes the `android-*` RID, so no extra configuration is required beyond providing a valid `ActivityReferenceProvider` (see `docs/android-lifecycle.md`).

## Development Notes

- When the AAR is absent, `NativeMessageBox.CrossPlatformSample.Android` falls back to compiling the Java bridge from `src/native/android/java/**`. This is useful while iterating on the native/Java code without repackaging.
- The script copies the resulting `.so` files into `artifacts/android/jni/<abi>` so they can be inspected or side-loaded if needed.
- The generated AAR includes a minimal manifest (`package="com.nativeinterop.nativemessagebox"`); if you need a different namespace, unzip the archive and adjust the manifest/class package prior to redistribution.

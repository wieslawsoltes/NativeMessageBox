param(
    [string]$Configuration = "Release",
    [string[]]$Targets,
    [switch]$All,
    [switch]$SkipTests,
    [switch]$SkipDotnet
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @"
Usage: build.ps1 [-Configuration <name>] [-Targets <host|android|ios> ...] [-All] [-SkipTests] [-SkipDotnet]

Examples:
  pwsh build/build.ps1
  pwsh build/build.ps1 -Configuration Debug -Targets host,android
  pwsh build/build.ps1 -All -SkipTests
"@
}

if ($PSBoundParameters.ContainsKey('Help')) {
    Show-Usage
    exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path "$scriptDir/.."
$artifacts = Join-Path $rootDir 'artifacts'
$nativeBuild = Join-Path $rootDir 'build/native'

if ($All) {
    $Targets = @('host', 'android', 'ios')
}

if (-not $Targets -or $Targets.Count -eq 0) {
    $Targets = @('host')
}

$normalizedTargets = @()
foreach ($target in $Targets) {
    if (-not [string]::IsNullOrWhiteSpace($target)) {
        $normalizedTargets += ($target -split ',')
    }
}

$targetOrder = @()
foreach ($target in $normalizedTargets) {
    $key = $target.Trim().ToLowerInvariant()
    if ($key -and -not $targetOrder.Contains($key)) {
        switch ($key) {
            'host' { $targetOrder += 'host' }
            'android' { $targetOrder += 'android' }
            'ios' { $targetOrder += 'ios' }
            default {
                throw "Unsupported target '$key'. Allowed values: host, android, ios."
            }
        }
    }
}

New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

function Invoke-HostBuild {
    param(
        [string]$Configuration,
        [switch]$SkipTests,
        [switch]$SkipDotnet
    )

    $nativeArtifacts = Join-Path $artifacts 'native'
    $nugetArtifacts = Join-Path $artifacts 'nuget'
    New-Item -ItemType Directory -Path $nativeArtifacts -Force | Out-Null
    New-Item -ItemType Directory -Path $nugetArtifacts -Force | Out-Null

    cmake -S $rootDir -B $nativeBuild -G Ninja "-DCMAKE_BUILD_TYPE=$Configuration"
    cmake --build $nativeBuild --config $Configuration

    if ($SkipTests) {
        Write-Host "Skipping native tests"
    }
    else {
        ctest --test-dir $nativeBuild --output-on-failure
    }

    $runtimeInfo = [System.Runtime.InteropServices.RuntimeInformation]
    $osMoniker = $null
    $libPattern = $null

    if ($runtimeInfo::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        $osMoniker = 'win'
        $libPattern = 'nativemessagebox.dll'
    }
    elseif ($runtimeInfo::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        $osMoniker = 'osx'
        $libPattern = 'libnativemessagebox.dylib'
    }
    elseif ($runtimeInfo::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        $osMoniker = 'linux'
        $libPattern = 'libnativemessagebox.so'
    }
    else {
        throw "Unsupported host platform: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
    }

    $processArch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    switch ($processArch) {
        ([System.Runtime.InteropServices.Architecture]::X64) { $archRid = 'x64' }
        ([System.Runtime.InteropServices.Architecture]::Arm64) { $archRid = 'arm64' }
        ([System.Runtime.InteropServices.Architecture]::Arm) { $archRid = 'arm' }
        ([System.Runtime.InteropServices.Architecture]::X86) { $archRid = 'x86' }
        default { $archRid = $processArch.ToString().ToLowerInvariant() }
    }

    $rid = "$osMoniker-$archRid"
    $lib = Get-ChildItem -Path $nativeBuild -Recurse -Filter $libPattern | Select-Object -First 1
    if ($lib) {
        $nativeOut = Join-Path $nativeArtifacts $rid
        if (Test-Path $nativeOut) { Remove-Item $nativeOut -Recurse -Force }
        New-Item -ItemType Directory -Path $nativeOut -Force | Out-Null
        Copy-Item $lib.FullName -Destination $nativeOut -Force

        $symbols = @()
        switch ($osMoniker) {
            'win' {
                $pdb = [System.IO.Path]::ChangeExtension($lib.FullName, '.pdb')
                if (Test-Path $pdb) {
                    Copy-Item $pdb -Destination $nativeOut -Force
                    $symbols += [System.IO.Path]::GetFileName($pdb)
                }
            }
            'osx' {
                $dsym = "$($lib.FullName).dSYM"
                if (Test-Path $dsym) {
                    Copy-Item $dsym -Destination $nativeOut -Recurse -Force
                    $symbols += [System.IO.Path]::GetFileName($dsym)
                }
            }
            'linux' {
                $debug = "$($lib.FullName).debug"
                if (Test-Path $debug) {
                    Copy-Item $debug -Destination $nativeOut -Force
                    $symbols += [System.IO.Path]::GetFileName($debug)
                }
            }
        }

        $version = git -C $rootDir describe --tags --always
        if (-not $version) { $version = '0.0.0' }
        $generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

        $manifestPath = Join-Path $nativeOut 'manifest.json'
        $symbolsJson = ($symbols | ForEach-Object { '"{0}"' -f $_ }) -join ', '
        if (-not $symbolsJson) { $symbolsJson = '' }
        @"
{
  "rid": "$rid",
  "library": "$(Split-Path -Leaf $lib.FullName)",
  "symbols": [ $symbolsJson ],
  "version": "$version",
  "generated": "$generated"
}
"@ | Out-File -FilePath $manifestPath -Encoding utf8 -Force

        $runtimeNativeDir = Join-Path (Join-Path $rootDir "src/dotnet/NativeMessageBox/runtimes/$rid") 'native'
        if (Test-Path $runtimeNativeDir) { Remove-Item $runtimeNativeDir -Recurse -Force }
        New-Item -ItemType Directory -Path $runtimeNativeDir -Force | Out-Null
        Copy-Item $lib.FullName -Destination $runtimeNativeDir -Force
        foreach ($symbol in $symbols) {
            $symbolPath = Join-Path $nativeOut $symbol
            if (Test-Path $symbolPath) {
                Copy-Item $symbolPath -Destination $runtimeNativeDir -Recurse -Force
            }
        }

        $zipPath = Join-Path $artifacts "native-$rid.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Push-Location $nativeArtifacts
        try {
            Compress-Archive -Path $rid -DestinationPath $zipPath -Force
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Warning "Unable to locate $libPattern under $nativeBuild"
    }

    if (-not $SkipDotnet) {
        dotnet restore (Join-Path $rootDir 'NativeMessageBox.sln')
        dotnet build (Join-Path $rootDir 'NativeMessageBox.sln') --configuration $Configuration --no-restore
        dotnet pack (Join-Path $rootDir 'src/dotnet/NativeMessageBox/NativeMessageBox.csproj') --configuration $Configuration --no-build --output $nugetArtifacts
    }
    else {
        Write-Host "Skipping dotnet restore/build/pack"
    }
}

function Resolve-AndroidJar {
    param(
        [string]$SdkRoot,
        [int]$TargetSdk
    )

    $candidate = Join-Path $SdkRoot "platforms/android-$TargetSdk/android.jar"
    if (Test-Path $candidate) {
        return $candidate
    }

    $platforms = Get-ChildItem -Path (Join-Path $SdkRoot 'platforms') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^android-\d+$' } |
        Sort-Object { [int]($_.Name.Split('-')[-1]) }

    foreach ($platform in ($platforms | Sort-Object { [int]($_.Name.Split('-')[-1]) })) {
        $jarPath = Join-Path $platform.FullName 'android.jar'
        if (Test-Path $jarPath) {
            $candidate = $jarPath
        }
    }
    return $candidate
}

function Invoke-AndroidPackaging {
    $buildRoot = Join-Path $rootDir 'build/android'
    $artifactDir = Join-Path $artifacts 'android'
    $aarName = 'NativeMessageBox.aar'

    $androidAbisRaw = $env:ANDROID_ABIS
    if ([string]::IsNullOrEmpty($androidAbisRaw)) {
        $abis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
    }
    else {
        $abis = $androidAbisRaw -split '\s+'
    }

    $androidApiLevel = if ($env:ANDROID_API_LEVEL) { [int]$env:ANDROID_API_LEVEL } else { 21 }
    $androidTargetSdk = if ($env:ANDROID_TARGET_SDK) { [int]$env:ANDROID_TARGET_SDK } else { 34 }

    $ndkRoot = $env:ANDROID_NDK_ROOT
    if ([string]::IsNullOrEmpty($ndkRoot)) { $ndkRoot = $env:ANDROID_NDK_HOME }
    if (-not $ndkRoot -or -not (Test-Path $ndkRoot)) {
        throw "Android NDK not found. Set ANDROID_NDK_ROOT (or ANDROID_NDK_HOME)."
    }

    $sdkRoot = $env:ANDROID_SDK_ROOT
    if ([string]::IsNullOrEmpty($sdkRoot)) { $sdkRoot = $env:ANDROID_HOME }
    if (-not $sdkRoot -or -not (Test-Path $sdkRoot)) {
        throw "Android SDK not found. Set ANDROID_SDK_ROOT (or ANDROID_HOME)."
    }

    $androidJar = Resolve-AndroidJar -SdkRoot $sdkRoot -TargetSdk $androidTargetSdk
    if (-not $androidJar -or -not (Test-Path $androidJar)) {
        throw "Unable to locate android.jar. Install platform tools for API $androidTargetSdk or newer."
    }

    $javaSrcDir = Join-Path $rootDir 'src/native/android/java'
    if (-not (Test-Path $javaSrcDir)) {
        throw "Java bridge sources not found at $javaSrcDir."
    }

    $toolchainFile = Join-Path $ndkRoot 'build/cmake/android.toolchain.cmake'
    if (-not (Test-Path $toolchainFile)) {
        throw "Unable to find android.toolchain.cmake at $toolchainFile."
    }

    if (Test-Path $buildRoot) { Remove-Item $buildRoot -Recurse -Force }
    if (Test-Path $artifactDir) { Remove-Item $artifactDir -Recurse -Force }
    New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

    foreach ($abi in $abis) {
        $abiBuild = Join-Path $buildRoot $abi
        Write-Host "Configuring $abi..."
        cmake `
            "-S" $rootDir `
            "-B" $abiBuild `
            "-G" "Ninja" `
            "-DCMAKE_BUILD_TYPE=Release" `
            "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile" `
            "-DANDROID_ABI=$abi" `
            "-DANDROID_PLATFORM=android-$androidApiLevel" `
            "-DBUILD_SHARED_LIBS=ON" `
            "-DBUILD_TESTING=OFF" `
            "-DANDROID_STL=c++_static"

        Write-Host "Building $abi..."
        cmake --build $abiBuild --target nativemessagebox

        $output = Get-ChildItem -Path $abiBuild -Recurse -Filter 'libnativemessagebox.so' | Select-Object -First 1
        if (-not $output) {
            throw "Failed to locate libnativemessagebox.so for $abi."
        }

        $aarAbiDir = Join-Path (Join-Path $buildRoot 'aar/jni') $abi
        New-Item -ItemType Directory -Path $aarAbiDir -Force | Out-Null
        Copy-Item $output.FullName -Destination $aarAbiDir -Force

        $artifactAbiDir = Join-Path (Join-Path $artifactDir 'jni') $abi
        New-Item -ItemType Directory -Path $artifactAbiDir -Force | Out-Null
        Copy-Item $output.FullName -Destination $artifactAbiDir -Force
    }

    $classesDir = Join-Path $buildRoot 'classes'
    New-Item -ItemType Directory -Path $classesDir -Force | Out-Null

    $javaSources = Get-ChildItem -Path $javaSrcDir -Recurse -Filter '*.java'
    if (-not $javaSources) {
        throw "No Java sources found under $javaSrcDir."
    }

    Write-Host "Compiling Java bridge..."
    $javacArgs = @(
        '-source', '1.8',
        '-target', '1.8',
        '-encoding', 'UTF-8',
        '-bootclasspath', $androidJar,
        '-classpath', $androidJar,
        '-d', $classesDir
    ) + ($javaSources | ForEach-Object { $_.FullName })
    & javac @javacArgs

    $classesJar = Join-Path $buildRoot 'classes.jar'
    & jar '--create' '--file' $classesJar '-C' $classesDir '.'

    $aarDir = Join-Path $buildRoot 'aar'
    Copy-Item $classesJar -Destination (Join-Path $aarDir 'classes.jar') -Force

    $manifestContent = @"
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="com.nativeinterop.nativemessagebox">
  <uses-sdk android:minSdkVersion="$androidApiLevel"
            android:targetSdkVersion="$androidTargetSdk" />
</manifest>
"@
    $androidManifestPath = Join-Path $aarDir 'AndroidManifest.xml'
    $manifestContent | Out-File -FilePath $androidManifestPath -Encoding utf8 -Force

    $aarPath = Join-Path $artifactDir $aarName
    if (Test-Path $aarPath) { Remove-Item $aarPath -Force }
    & jar '--create' '--file' $aarPath '-C' $aarDir '.'

    $version = git -C $rootDir describe --tags --always
    if (-not $version) { $version = '0.0.0' }
    $generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    $quotedAbis = $abis | ForEach-Object { '"{0}"' -f $_ }
    $manifestJson = @"
{
  "name": "$aarName",
  "abis": [$(($quotedAbis -join ', '))],
  "apiLevel": $androidApiLevel,
  "targetSdk": $androidTargetSdk,
  "version": "$version",
  "generated": "$generated"
}
"@
    $manifestPath = Join-Path $artifactDir 'manifest.json'
    $manifestJson | Out-File -FilePath $manifestPath -Encoding utf8 -Force

    Write-Host "Android AAR created at $aarPath"
}

function Invoke-IosPackaging {
    param(
        [string]$Configuration
    )

    $runtimeInfo = [System.Runtime.InteropServices.RuntimeInformation]
    if (-not $runtimeInfo::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        Write-Warning "iOS packaging requires a macOS host. Skipping."
        return
    }

    $packageScript = Join-Path $scriptDir 'scripts/package-ios-xcframework.sh'
    if (-not (Test-Path $packageScript)) {
        throw "Unable to locate iOS packaging script at $packageScript."
    }

    $previousConfig = $env:CONFIGURATION
    try {
        $env:CONFIGURATION = $Configuration
        & bash $packageScript
    }
    finally {
        if ($null -eq $previousConfig) {
            Remove-Item Env:CONFIGURATION -ErrorAction SilentlyContinue
        }
        else {
            $env:CONFIGURATION = $previousConfig
        }
    }
}

foreach ($target in $targetOrder) {
    switch ($target) {
        'host' {
            Invoke-HostBuild -Configuration $Configuration -SkipTests:$SkipTests -SkipDotnet:$SkipDotnet
        }
        'android' {
            Invoke-AndroidPackaging
        }
        'ios' {
            Invoke-IosPackaging -Configuration $Configuration
        }
    }
}

Write-Host "Artifacts available under $artifacts"

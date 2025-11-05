param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path "$scriptDir/.."
$artifacts = Join-Path $rootDir 'artifacts'
$nativeBuild = Join-Path $rootDir 'build/native'

New-Item -ItemType Directory -Path (Join-Path $artifacts 'nuget') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $artifacts 'native') -Force | Out-Null

cmake -S $rootDir -B $nativeBuild -G Ninja -DCMAKE_BUILD_TYPE=$Configuration
cmake --build $nativeBuild --config $Configuration
ctest --test-dir $nativeBuild --output-on-failure

$arch = $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()
switch ($arch) {
    'amd64' { $archRid = 'x64' }
    'arm64' { $archRid = 'arm64' }
    default { $archRid = $arch }
}

$rid = "win-$archRid"
$libPattern = 'nativemessagebox.dll'
$lib = Get-ChildItem -Path $nativeBuild -Recurse -Filter $libPattern | Select-Object -First 1
if ($lib) {
    $nativeOut = Join-Path (Join-Path $artifacts 'native') $rid
    New-Item -ItemType Directory -Path $nativeOut -Force | Out-Null
    Copy-Item $lib.FullName -Destination $nativeOut -Force

    $pdb = [System.IO.Path]::ChangeExtension($lib.FullName, '.pdb')
    $symbols = @()
    if (Test-Path $pdb) {
        Copy-Item $pdb -Destination $nativeOut -Force
        $symbols += [System.IO.Path]::GetFileName($pdb)
    }

    $version = git -C $rootDir describe --tags --always
    if (-not $version) { $version = '0.0.0' }

    $manifestPath = Join-Path $nativeOut 'manifest.json'
    $symbolsJson = ($symbols | ForEach-Object { '"{0}"' -f $_ }) -join ', '
    if (-not $symbolsJson) { $symbolsJson = '' }
    @"
{
  "rid": "$rid",
  "library": "$(Split-Path -Leaf $lib.FullName)",
  "symbols": [ $symbolsJson ],
  "version": "$version",
  "generated": "$(Get-Date -Format o)"
}
"@ | Out-File -FilePath $manifestPath -Encoding utf8 -Force

    $runtimeDir = Join-Path (Join-Path $rootDir 'src/dotnet/NativeMessageBox/runtimes') $rid
    $runtimeNativeDir = Join-Path $runtimeDir 'native'
    New-Item -ItemType Directory -Path $runtimeNativeDir -Force | Out-Null
    Copy-Item $lib.FullName -Destination $runtimeNativeDir -Force
    foreach ($symbol in $symbols) {
        $symbolPath = Join-Path $nativeOut $symbol
        if (Test-Path $symbolPath) {
            Copy-Item $symbolPath -Destination $runtimeNativeDir -Force
        }
    }

    $zipPath = Join-Path $artifacts "native-$rid.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $nativeOut '*') -DestinationPath $zipPath
}

dotnet restore (Join-Path $rootDir 'NativeMessageBox.sln')
dotnet build (Join-Path $rootDir 'NativeMessageBox.sln') --configuration $Configuration --no-restore
dotnet pack (Join-Path $rootDir 'src/dotnet/NativeMessageBox/NativeMessageBox.csproj') --configuration $Configuration --no-build --output (Join-Path $artifacts 'nuget')

Write-Host "Artifacts available under $artifacts"

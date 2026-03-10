$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot
dotnet tool restore
Push-Location (Join-Path $PSScriptRoot 'site')
try {
    dotnet tool run lunet --stacktrace build
}
finally {
    Pop-Location
}

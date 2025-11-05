param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path "$scriptDir/.."

& dotnet run --project (Join-Path $rootDir 'DialogPlayground/DialogPlayground.csproj') -- @Args

param(
    [ValidateSet("up", "update", "down", "restart", "status", "logs")]
    [string]$Command = "up",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force "user/fonts" | Out-Null

$composeArgs = @("-f", "compose.release.yml")
$licensePath = Join-Path $PSScriptRoot "user/license-key"
if ((Test-Path -LiteralPath $licensePath -PathType Leaf) -and
    (Get-Item -LiteralPath $licensePath).Length -gt 0) {
    $composeArgs += @("-f", "compose.license.yml")
}

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose @composeArgs @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

switch ($Command) {
    "up"      { Invoke-Compose (@("up", "-d") + $ExtraArgs) }
    "update"  {
        Invoke-Compose @("pull")
        Invoke-Compose (@("up", "-d") + $ExtraArgs)
    }
    "down"    { Invoke-Compose (@("down") + $ExtraArgs) }
    "restart" { Invoke-Compose (@("restart") + $ExtraArgs) }
    "status"  { Invoke-Compose (@("ps") + $ExtraArgs) }
    "logs"    { Invoke-Compose (@("logs", "-f") + $ExtraArgs) }
}

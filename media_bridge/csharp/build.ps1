$ErrorActionPreference = "Stop"

$projDir = Join-Path $PSScriptRoot "MediaBridge"
& dotnet publish $projDir -c Release -r win-x64
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

$publishDir = Join-Path $projDir "bin\Release\net8.0-windows10.0.19041.0\win-x64\publish"
$target = Join-Path $PSScriptRoot "..\media_bridge.exe"
Copy-Item (Join-Path $publishDir "media_bridge.exe") $target -Force

Write-Host "Built and copied to $target"

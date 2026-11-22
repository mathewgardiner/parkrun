# Records an event's Saturday start time in data/start-times.json.
#   scripts\set-start-time.ps1 -Event 'Willoughby' -Time '7:00am'
# Use the event name exactly as build.ps1's "MISSING START TIME" warning prints it,
# and the time exactly as scripts/extract-start-time.js returns it.
param(
  [Parameter(Mandatory)][string]$Event,
  [Parameter(Mandatory)][string]$Time
)
$ErrorActionPreference = 'Stop'
if ($Time -notmatch '^\d{1,2}:\d{2}[ap]m$') { throw "'$Time' isn't a time like 7:00am" }
$path = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\start-times.json'
$map = [ordered]@{}
if (Test-Path $path) { ([System.IO.File]::ReadAllText($path) | ConvertFrom-Json).PSObject.Properties | % { $map[$_.Name] = $_.Value } }
$map[$Event] = $Time
$sorted = [ordered]@{}; $map.Keys | sort | % { $sorted[$_] = $map[$_] }
[System.IO.File]::WriteAllText($path, ($sorted | ConvertTo-Json) + "`n", (New-Object System.Text.UTF8Encoding $false))
"$Event -> $Time"

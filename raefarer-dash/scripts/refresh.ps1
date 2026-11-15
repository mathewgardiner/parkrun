# Weekly refresh, local part. Run after saving the three data/A<id>.txt files.
#   1. downloads parkrun's event feed
#   2. warns about any parkrun within 60 km of Cammeray that is on neither
#      data/sydney-events.json nor data/not-raefarer.json (a possible new Raefarer event)
#   3. runs build.ps1
# Then upload dist/*.json and run dataset-docs.ps1 (see REFRESH.md).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$data = Join-Path $root 'data'

Invoke-WebRequest 'https://images.parkrun.com/events.json' -OutFile (Join-Path $data 'events.json') -UseBasicParsing
"events.json downloaded"

$known = @{}
(([System.IO.File]::ReadAllText((Join-Path $data 'sydney-events.json')) | ConvertFrom-Json) | % { $_ }) | % { $known[$_.name] = $true }
(([System.IO.File]::ReadAllText((Join-Path $data 'not-raefarer.json')) | ConvertFrom-Json) | % { $_ }) | % { $known[$_] = $true }
$feed = ([System.IO.File]::ReadAllText((Join-Path $data 'events.json')) | ConvertFrom-Json).events.features |
  ? { $_.properties.seriesid -eq 1 -and $_.properties.countrycode -eq 3 }
$r = [math]::PI / 180
foreach ($f in $feed) {
  $lat = $f.geometry.coordinates[1]; $lon = $f.geometry.coordinates[0]
  $x = [math]::Pow([math]::Sin(($lat + 33.8217) * $r / 2), 2) + [math]::Cos(-33.8217 * $r) * [math]::Cos($lat * $r) * [math]::Pow([math]::Sin(($lon - 151.2117) * $r / 2), 2)
  $km = 2 * 6371 * [math]::Asin([math]::Sqrt($x))
  $name = $f.properties.EventLongName -replace ' parkrun', ''
  if ($km -le 60 -and -not $known[$name]) { Write-Warning ("NEW EVENT NEAR SYDNEY: {0} ({1:N1} km, {2}, {3}) - ask the user whether it counts for Raefarer" -f $name, $km, $lat, $lon) }
}

& (Join-Path $PSScriptRoot 'build.ps1')
& (Join-Path $PSScriptRoot 'share-card.ps1')
& (Join-Path $PSScriptRoot 'site.ps1')
& (Join-Path $PSScriptRoot 'publish-site.ps1')

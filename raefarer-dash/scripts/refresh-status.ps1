# Where this week's refresh stands, from the runner files (data/A<id>.txt).
#   refresh-status.ps1        prints, for each runner, whether this week's result is in, then three summary lines:
#                               ALL RESULTS IN: YES | NO       every runner's latest run is this week
#                               NEW SINCE LAST BUILD: <names> | none   runs or volunteer credits changed since the last -Mark
#                               WEEK DONE: YES | NO            all results in, and nothing new to build
#   refresh-status.ps1 -Mark  records the runner files as built (last step of a refresh), in dist/last-build.json (not committed)
# "This week" starts at midnight on the most recent Saturday.
param([switch]$Mark)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$snapFile = Join-Path $root 'dist\last-build.json'
$now = Get-Date
$weekStart = $now.Date.AddDays(-(([int]$now.DayOfWeek + 1) % 7))   # most recent Saturday (today if Saturday)

$runners = foreach ($f in Get-ChildItem (Join-Path $root 'data') -Filter 'A*.txt' | Sort-Object Name) {
  $head = @([System.IO.File]::ReadAllLines($f.FullName) | ? { $_ -like '#*' })
  $num = { param($label) $l = $head | ? { $_ -match "^#\s*$label\s*:" } | select -First 1; if ($l) { [int]([regex]::Match($l, ':\s*(\d+)').Groups[1].Value) } else { $null } }
  $latestLine = $head | ? { $_ -match '^#\s*Latest run\s*:' } | select -First 1
  $latest = $null; $latestText = 'unknown'
  if ($latestLine) {
    $latestText = ($latestLine -replace '^#\s*Latest run\s*:\s*', '').Trim()
    $m = [regex]::Match($latestText, '^(\d{4}-\d{2}-\d{2})')
    if ($m.Success) { $latest = [datetime]::ParseExact($m.Groups[1].Value, 'yyyy-MM-dd', $null) }
  }
  [pscustomobject]@{
    id      = $f.BaseName
    name    = [regex]::Match($head[0], '#\s*(\S+)').Groups[1].Value
    total   = & $num 'total'
    credits = & $num 'Volunteer credits'
    latest  = $latestText
    inWeek  = [bool]($latest -and $latest -ge $weekStart)
  }
}

if ($Mark) {
  $snap = [ordered]@{}
  foreach ($r in $runners) { $snap[$r.id] = [ordered]@{ total = $r.total; credits = $r.credits } }
  New-Item -ItemType Directory -Force (Split-Path $snapFile) | Out-Null
  [System.IO.File]::WriteAllText($snapFile, ($snap | ConvertTo-Json))
  "build recorded: " + (($runners | % { "$($_.name) $($_.total) runs, $($_.credits) credits" }) -join '; ')
  return
}

$snap = $null
if (Test-Path $snapFile) { $snap = [System.IO.File]::ReadAllText($snapFile) | ConvertFrom-Json }
$new = @(foreach ($r in $runners) {
  $s = if ($snap) { $snap.($r.id) } else { $null }
  if (-not $s -or $s.total -ne $r.total -or $s.credits -ne $r.credits) { $r.name }
})

foreach ($r in $runners) {
  if ($r.inWeek) { "$($r.name): this week's result is in ($($r.latest))" }
  else { "$($r.name): no result this week yet (latest $($r.latest))" }
}
$all = -not ($runners | ? { -not $_.inWeek })
"ALL RESULTS IN: " + $(if ($all) { 'YES' } else { 'NO' })
"NEW SINCE LAST BUILD: " + $(if ($new.Count) { $new -join ', ' } else { 'none' })
"WEEK DONE: " + $(if ($all -and -not $new.Count) { 'YES' } else { 'NO' })

# Where this week's refresh stands, from the runner files (data/A<id>.txt) and data/results-to.json.
#   refresh-status.ps1             prints, for each runner, whether this week's result is in, then three summary lines:
#                                    ALL RESULTS IN: YES | NO       everyone's "results to" date is this week
#                                    NEW SINCE LAST BUILD: <names> | none   runs, credits or "results to" changed since the last -Mark
#                                    WEEK DONE: YES | NO            all results in, and nothing new to build
#   refresh-status.ps1 -CloseWeek  last attempt of the week: confirms this Saturday as "results to" for anyone
#                                  without a result this week (writes data/results-to.json)
#   refresh-status.ps1 -Mark       records the runner files as built (last step of a refresh), in dist/last-build.json (not committed)
# "This week" starts at midnight on the most recent Saturday. A runner's "results to" date is the later of their
# latest run and their confirmed Saturday; build.ps1 uses the same rule for the page.
param([switch]$Mark, [switch]$CloseWeek)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$snapFile = Join-Path $root 'dist\last-build.json'
$ctFile = Join-Path $root 'data\results-to.json'
$now = Get-Date
$weekStart = $now.Date.AddDays(-(([int]$now.DayOfWeek + 1) % 7))   # most recent Saturday (today if Saturday)
$enc = New-Object System.Text.UTF8Encoding $false

$confirmed = [ordered]@{}
if (Test-Path $ctFile) { ([System.IO.File]::ReadAllText($ctFile) | ConvertFrom-Json).PSObject.Properties | % { $confirmed[$_.Name] = [string]$_.Value } }

function Get-Runners {
  foreach ($f in Get-ChildItem (Join-Path $root 'data') -Filter 'A*.txt' | Sort-Object Name) {
    $head = @([System.IO.File]::ReadAllLines($f.FullName) | ? { $_ -like '#*' })
    $num = { param($label) $l = $head | ? { $_ -match "^#\s*$label\s*:" } | select -First 1; if ($l) { [int]([regex]::Match($l, ':\s*(\d+)').Groups[1].Value) } else { $null } }
    $latestLine = $head | ? { $_ -match '^#\s*Latest run\s*:' } | select -First 1
    $latestText = if ($latestLine) { ($latestLine -replace '^#\s*Latest run\s*:\s*', '').Trim() } else { 'unknown' }
    $latestDate = [regex]::Match($latestText, '^(\d{4}-\d{2}-\d{2})').Groups[1].Value
    $to = @($latestDate, $confirmed[$f.BaseName] | ? { $_ }) | sort -Descending | select -First 1
    [pscustomobject]@{
      id      = $f.BaseName
      name    = [regex]::Match($head[0], '#\s*(\S+)').Groups[1].Value
      total   = & $num 'total'
      credits = & $num 'Volunteer credits'
      latest  = $latestText
      to      = [string]$to
      inWeek  = [bool]($to -and [datetime]::ParseExact($to, 'yyyy-MM-dd', $null) -ge $weekStart)
    }
  }
}
$runners = @(Get-Runners)

if ($CloseWeek) {
  $sat = $weekStart.ToString('yyyy-MM-dd')
  $closed = @($runners | ? { -not $_.inWeek })
  foreach ($r in $closed) { $confirmed[$r.id] = $sat }
  [System.IO.File]::WriteAllText($ctFile, ($confirmed | ConvertTo-Json), $enc)
  if ($closed.Count) { "results to $sat confirmed for: " + (($closed | % { $_.name }) -join ', ') } else { 'everyone already has a result this week' }
  return
}

if ($Mark) {
  $snap = [ordered]@{}
  foreach ($r in $runners) { $snap[$r.id] = [ordered]@{ total = $r.total; credits = $r.credits; to = $r.to } }
  New-Item -ItemType Directory -Force (Split-Path $snapFile) | Out-Null
  [System.IO.File]::WriteAllText($snapFile, ($snap | ConvertTo-Json), $enc)
  "build recorded: " + (($runners | % { "$($_.name) $($_.total) runs, $($_.credits) credits, results to $($_.to)" }) -join '; ')
  return
}

$snap = $null
if (Test-Path $snapFile) { $snap = [System.IO.File]::ReadAllText($snapFile) | ConvertFrom-Json }
$new = @(foreach ($r in $runners) {
  $s = if ($snap) { $snap.($r.id) } else { $null }
  if (-not $s -or $s.total -ne $r.total -or $s.credits -ne $r.credits -or [string]$s.to -ne $r.to) { $r.name }
})

foreach ($r in $runners) {
  if ($r.inWeek -and $r.latest -notlike "$($r.to)*") { "$($r.name): no run this week, confirmed (results to $($r.to); latest run $($r.latest))" }
  elseif ($r.inWeek) { "$($r.name): this week's result is in (results to $($r.to); latest run $($r.latest))" }
  else { "$($r.name): no result this week yet (latest run $($r.latest))" }
}
$all = -not ($runners | ? { -not $_.inWeek })
"ALL RESULTS IN: " + $(if ($all) { 'YES' } else { 'NO' })
"NEW SINCE LAST BUILD: " + $(if ($new.Count) { $new -join ', ' } else { 'none' })
"WEEK DONE: " + $(if ($all -and -not $new.Count) { 'YES' } else { 'NO' })

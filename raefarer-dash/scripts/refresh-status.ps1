# Has the weekly refresh already finished this week?
#   refresh-status.ps1        prints 'REFRESHED THIS WEEK: YES (<date>)' or 'REFRESHED THIS WEEK: NO (last <date or never>)'
#   refresh-status.ps1 -Mark  records that a refresh finished now (last step of the weekly refresh)
# "This week" starts at midnight on the most recent Saturday. The record is dist/last-refresh.txt (not committed).
param([switch]$Mark)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$file = Join-Path $root 'dist\last-refresh.txt'
$now = Get-Date

if ($Mark) {
  New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
  [System.IO.File]::WriteAllText($file, $now.ToString('yyyy-MM-dd HH:mm'))
  "refresh recorded: " + $now.ToString('yyyy-MM-dd HH:mm')
  return
}

$weekStart = $now.Date.AddDays(-(([int]$now.DayOfWeek + 1) % 7))   # most recent Saturday (today if Saturday)
if (Test-Path $file) {
  $last = [datetime]::ParseExact(([System.IO.File]::ReadAllText($file)).Trim(), 'yyyy-MM-dd HH:mm', $null)
  if ($last -ge $weekStart) { "REFRESHED THIS WEEK: YES (" + $last.ToString('yyyy-MM-dd HH:mm') + ")"; return }
  "REFRESHED THIS WEEK: NO (last " + $last.ToString('yyyy-MM-dd HH:mm') + ")"
} else {
  "REFRESHED THIS WEEK: NO (last never)"
}

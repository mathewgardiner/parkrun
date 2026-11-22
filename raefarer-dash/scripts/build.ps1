# Builds every number the dashboard shows, from the files in data/.
# The page (src/index.html) only displays these files; all rules live here.
#
# Inputs
#   data/events.json         parkrun events feed (https://images.parkrun.com/events.json)
#   data/sydney-events.json  the 36 Raefarer events + drive time from Cammeray (OSRM, free-flow)
#   data/retired-events.json closed events: no "isn't in the current event feed" warning
#   data/raefarer-latched.json  each runner's most Raefarer rounds finished (written by this build)
#   data/milestones.json     parkrun's milestone t-shirt counts, for runs and volunteer credits
#   data/start-times.json    Saturday start time per event name (scripts/set-start-time.ps1)
#   data/A<id>.txt           one per runner, copied from their public profile:
#                              '# Name SURNAME (A123) ...'          first line
#                              '# total: N'                         total parkruns
#                              '# Volunteer credits: N'             "Total Credits" row of the Volunteer Summary
#                              '# Volunteer roles: Role n, Role n'  (kept for reference)
#                            rows: 'Event|Runs|BestTime' (Event Summaries table)
#                               or 'Event|Date|Time|AgeGrade|PB' (full results list)
#
# Outputs (dist/)
#   runners.json       one row per runner: totals, credits, Raefarer rounds
#   sydney_table.json  one row per Raefarer event: runs and need per runner
#   combos.json        one row per (who's going, event): ranked for that group
#   nendy.json         each runner's 5 nearest events not yet run
#   family.json        one row of family totals
#   page.json          src/index.html wrapped as the dashboard's page document
#
# Rules
#   Raefarer rounds: an event counts toward finished rounds only once at least one of
#     the family has run it. Until then (e.g. a newly launched event) it doesn't hold
#     anyone back; as soon as one of us runs it, it counts for everyone.
#     finished = lowest run count across counted events, but never below the runner's
#     best so far (data/raefarer-latched.json): a newly launched event doesn't undo a
#     finished round, it joins the round being worked on. next round = finished + 1;
#     a runner "needs" an event when their run count there is below their next round.
#   Who's going ranking, for a group G:
#     1. most of G need it   2. fewest of the rest need it (save shared ones for later)
#     3. shortest drive.
#   NENDY: nearest event not run yet, straight line from Cammeray, any parkrun.
#   Next milestone: the first count in data/milestones.json above the runner's total.
#     Its date assumes a run on every coming Saturday, plus Christmas Day and New Year's
#     Day when they aren't Saturdays (one result counts per day). The page can push it
#     back by "parkruns I'll miss" using family.run_dates.
#
# -ListMissingStartTimes: only print the events the page shows that have no entry in
#   data/start-times.json (with their parkrun page), and write nothing.

param([switch]$ListMissingStartTimes)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$data = Join-Path $root 'data'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

# Display order and colour keys (Judi orange, Katie blue, Mathew green).
$family = @(
  [pscustomobject]@{ id = 'A7342171'; key = 'judi' },
  [pscustomobject]@{ id = 'A3947996'; key = 'katie' },
  [pscustomobject]@{ id = 'A7157558'; key = 'mathew' }
)
$homeLat = -33.8217; $homeLon = 151.2117   # Cammeray

function Get-Km($lat, $lon) {
  $r = [math]::PI / 180; $dLat = ($lat - $homeLat) * $r; $dLon = ($lon - $homeLon) * $r
  $x = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($homeLat * $r) * [math]::Cos($lat * $r) * [math]::Pow([math]::Sin($dLon / 2), 2)
  [math]::Round(2 * 6371 * [math]::Asin([math]::Sqrt($x)), 1)
}
function To-Sec($t) { $p = $t.Split(':') | % { [int]$_ }; if ($p.Count -eq 3) { $p[0]*3600 + $p[1]*60 + $p[2] } else { $p[0]*60 + $p[1] } }
function Read-Json($path) { @(([System.IO.File]::ReadAllText($path) | ConvertFrom-Json)) | % { $_ } }
function Save($name, $rows) {
  $json = ConvertTo-Json @($rows) -Depth 5 -Compress
  [System.IO.File]::WriteAllText((Join-Path $dist $name), $json, (New-Object System.Text.UTF8Encoding $false))
  "{0,-18} {1} rows" -f $name, @($rows).Count
}

# ---- events feed, keyed by display name ("X parkrun, Place" -> "X, Place")
$feed = ([System.IO.File]::ReadAllText((Join-Path $data 'events.json')) | ConvertFrom-Json).events.features | ? { $_.properties.seriesid -eq 1 }
$byName = @{}
foreach ($f in $feed) {
  $n = $f.properties.EventLongName -replace ' parkrun', ''
  $byName[$n] = [pscustomobject]@{ event = $n; lat = $f.geometry.coordinates[1]; lon = $f.geometry.coordinates[0]; country = $f.properties.countrycode }
}
# Events known to be closed: still counted in run totals, but no "not in feed" warning.
$retired = @{}
$retiredPath = Join-Path $data 'retired-events.json'
if (Test-Path $retiredPath) { Read-Json $retiredPath | % { $retired[$_] = $true } }
# slug and site for each event (for start-time lookups)
$slugOf = @{}
foreach ($f in $feed) { $slugOf[($f.properties.EventLongName -replace ' parkrun', '')] = [pscustomobject]@{ slug = $f.properties.eventname; country = $f.properties.countrycode } }

# ---- milestone t-shirts and Saturday start times
$milestones = [System.IO.File]::ReadAllText((Join-Path $data 'milestones.json')) | ConvertFrom-Json
$startTimes = @{}
$stPath = Join-Path $data 'start-times.json'
if (Test-Path $stPath) { ([System.IO.File]::ReadAllText($stPath) | ConvertFrom-Json).PSObject.Properties | % { $startTimes[$_.Name] = $_.Value } }
function StartOf($ev) { if ($startTimes.Contains($ev)) { [string]$startTimes[$ev] } else { '' } }

# ---- Raefarer list
$sydney = Read-Json (Join-Path $data 'sydney-events.json') | % {
  [pscustomobject]@{ event = $_.name; lat = [double]$_.lat; lon = [double]$_.lon; drive_mins = [int]$_.mins; drive_km = [double]$_.km }
}

# ---- runner files
$runs = @{}      # runs[key][event] = count
$best = @{}      # best[key][event] = PB at that event
$info = @{}
foreach ($m in $family) {
  $path = Join-Path $data "$($m.id).txt"
  $lines = [System.IO.File]::ReadAllLines($path)
  $head = @($lines | ? { $_ -like '#*' })
  $rows = @($lines | ? { $_ -and $_ -notlike '#*' })
  $fullName = [regex]::Match($head[0], '#\s*(.+?)\s*\(A\d+\)').Groups[1].Value
  $first = (Get-Culture).TextInfo.ToTitleCase($fullName.Split(' ')[0].ToLower())
  $hdr = { param($label) $l = $head | ? { $_ -match "^#\s*$label\s*:" } | select -First 1; if ($l) { [int]([regex]::Match($l, ':\s*(\d+)').Groups[1].Value) } else { $null } }
  $credits = & $hdr 'Volunteer credits'
  if ($null -eq $credits) { throw "$($m.id): missing '# Volunteer credits: N' line" }
  $total = & $hdr 'total'

  $agg = [ordered]@{}
  foreach ($r in $rows) {
    $c = $r.Split('|')
    if ($c.Count -ge 5) { $ev = $c[0]; $n = 1; $t = $c[2] } else { $ev = $c[0]; $n = [int]$c[1]; $t = $c[2] }
    if (-not $agg.Contains($ev)) { $agg[$ev] = @{ runs = 0; best = $t } }
    $agg[$ev].runs += $n
    if ((To-Sec $t) -lt (To-Sec $agg[$ev].best)) { $agg[$ev].best = $t }
  }
  if ($null -eq $total) { $total = ($agg.Values | % { $_.runs } | measure -Sum).Sum }
  foreach ($ev in $agg.Keys) { if (-not $byName[$ev] -and -not $retired[$ev]) { Write-Warning "$($m.id): '$ev' isn't in the current event feed (retired or renamed?)" } }

  $runs[$m.key] = @{}; foreach ($ev in $agg.Keys) { $runs[$m.key][$ev] = $agg[$ev].runs }
  $best[$m.key] = @{}; foreach ($ev in $agg.Keys) { $best[$m.key][$ev] = $agg[$ev].best }
  $homeEv = $agg.Keys | sort { -$agg[$_].runs } | select -First 1
  $fast = $agg.Keys | sort { To-Sec $agg[$_].best } | select -First 1
  $info[$m.key] = [ordered]@{
    runner_id = $m.id; key = $m.key; name = $first; total_runs = $total; events_visited = $agg.Count
    volunteer_credits = $credits; credits_per_100 = [math]::Round(100 * $credits / $total, 1)
    fastest_time = $agg[$fast].best; fastest_event = $fast; home_event = $homeEv; home_runs = $agg[$homeEv].runs
  }
}
function RunsAt($key, $ev) { $v = $runs[$key][$ev]; if ($v) { [int]$v } else { 0 } }
function PbAt($key, $ev) { $v = $best[$key][$ev]; if ($v) { [string]$v } else { '' } }

# ---- upcoming parkrun days, for milestone dates
# Every Saturday, plus Christmas Day and New Year's Day when they aren't Saturdays
# (one result counts per day). Assumes a run on each, from the day after the build.
$today = (Get-Date).Date
$runDays = for ($d = $today.AddDays(1); $d -le $today.AddYears(3); $d = $d.AddDays(1)) {
  $special = ($d.Month -eq 12 -and $d.Day -eq 25) -or ($d.Month -eq 1 -and $d.Day -eq 1)
  if ($d.DayOfWeek -eq 'Saturday' -or $special) { $d }
}
function NextMilestone($list, $n) { $list | ? { $_ -gt $n } | select -First 1 }

# ---- Raefarer rounds
$counted = @($sydney | ? { $e = $_.event; @($family | ? { (RunsAt $_.key $e) -gt 0 }).Count -gt 0 })
$asOf = (Get-Date).ToString('yyyy-MM-dd')
# Finished rounds are latched: a new event never takes a round away (data/raefarer-latched.json).
$latchPath = Join-Path $data 'raefarer-latched.json'
$latched = @{}
if (Test-Path $latchPath) { ([System.IO.File]::ReadAllText($latchPath) | ConvertFrom-Json).PSObject.Properties | % { $latched[$_.Name] = [int]$_.Value } }
$runnerRows = foreach ($m in $family) {
  $i = $info[$m.key]
  $computed = if ($counted.Count) { ($counted | % { RunsAt $m.key $_.event } | measure -Minimum).Minimum } else { 0 }
  $finished = [math]::Max([int]$computed, [int]$latched[$m.key])
  $latched[$m.key] = $finished
  $next = $finished + 1
  $i.raefarer_finished = [int]$finished
  $i.next_round = $next
  $i.done_next = @($sydney | ? { (RunsAt $m.key $_.event) -ge $next }).Count
  $i.raefarer_total = $sydney.Count
  $i.sydney_done = @($sydney | ? { (RunsAt $m.key $_.event) -gt 0 }).Count
  $i.as_of = $asOf
  $ms = NextMilestone $milestones.runs $i.total_runs
  $i.next_milestone = [int]$ms
  $i.runs_to_go = [int]($ms - $i.total_runs)
  $i.milestone_date = if ($ms -and $i.runs_to_go -le $runDays.Count) { $runDays[$i.runs_to_go - 1].ToString('yyyy-MM-dd') } else { '' }
  $vm = NextMilestone $milestones.volunteer $i.volunteer_credits
  $i.next_vol_milestone = [int]$vm
  $i.vol_to_go = [int]($vm - $i.volunteer_credits)
  [pscustomobject]$i
}
$nextOf = @{}; $runnerRows | % { $nextOf[$_.key] = $_.next_round }

# ---- per-event table
$table = foreach ($e in $sydney) {
  $row = [ordered]@{ event = $e.event; drive_mins = $e.drive_mins; start_time = (StartOf $e.event); lat = $e.lat; lon = $e.lon
    counted = [bool]($counted | ? { $_.event -eq $e.event }) }
  $needAny = 0
  foreach ($m in $family) {
    $n = RunsAt $m.key $e.event
    $need = [int]($n -lt $nextOf[$m.key])
    $row["runs_$($m.key)"] = $n; $row["need_$($m.key)"] = $need; $row["pb_$($m.key)"] = (PbAt $m.key $e.event); $needAny += $need
  }
  $row.needed_by = $needAny
  [pscustomobject]$row
}

# ---- who's going: every non-empty group, in display order
$combos = @()
for ($mask = 1; $mask -lt [math]::Pow(2, $family.Count); $mask++) {
  $going = @(); $rest = @()
  for ($b = 0; $b -lt $family.Count; $b++) { if ($mask -band [math]::Pow(2, $b)) { $going += $family[$b].key } else { $rest += $family[$b].key } }
  $combo = $going -join '+'
  $ranked = $table | % {
    $t = $_
    $ng = @($going | ? { $t."need_$_" -eq 1 }).Count
    $no = @($rest | ? { $t."need_$_" -eq 1 }).Count
    [pscustomobject]@{ t = $t; ng = $ng; no = $no }
  } | sort @{ e = { $_.ng }; Descending = $true }, @{ e = { $_.no } }, @{ e = { $_.t.drive_mins } }, @{ e = { $_.t.event } }
  $rank = 0
  foreach ($x in $ranked) {
    $rank++
    $row = [ordered]@{ combo = $combo; rank = $rank; event = $x.t.event; needed_by_going = $x.ng; going = $going.Count; needed_by_others = $x.no; drive_mins = $x.t.drive_mins; start_time = $x.t.start_time; counted = $x.t.counted }
    foreach ($m in $family) { $row["runs_$($m.key)"] = $x.t."runs_$($m.key)"; $row["need_$($m.key)"] = $x.t."need_$($m.key)"; $row["pb_$($m.key)"] = $x.t."pb_$($m.key)" }
    $combos += [pscustomobject]$row
  }
}

# ---- NENDY
$nearby = $byName.Values | % { [pscustomobject]@{ event = $_.event; lat = $_.lat; lon = $_.lon; dist_km = (Get-Km $_.lat $_.lon) } } | ? { $_.dist_km -le 400 } | sort dist_km
$nendy = foreach ($m in $family) {
  $rank = 0
  foreach ($e in ($nearby | ? { (RunsAt $m.key $_.event) -eq 0 } | select -First 5)) {
    $rank++
    [pscustomobject]@{ runner_id = $m.id; key = $m.key; name = $info[$m.key].name; rank = $rank; event = $e.event; dist_km = $e.dist_km; start_time = (StartOf $e.event); lat = $e.lat; lon = $e.lon }
  }
}

# ---- events shown on the page with no start time yet (the weekly refresh looks these up)
$missingStart = @(@($table | % { $_.event }) + @($nendy | % { $_.event }) | select -Unique | ? { -not (StartOf $_) })
foreach ($ev in $missingStart) {
  $s = $slugOf[$ev]
  $site = if ($s.country -eq 65) { 'www.parkrun.co.nz' } else { 'www.parkrun.com.au' }
  "MISSING START TIME: $ev | https://$site/$($s.slug)/"
}
if ($ListMissingStartTimes) { if (-not $missingStart.Count) { 'No start times missing' }; return }

# ---- family totals
$allEvents = @{}; foreach ($m in $family) { foreach ($ev in $runs[$m.key].Keys) { $allEvents[$ev] = 1 + [int]$allEvents[$ev] } }
$familyRow = [pscustomobject]@{
  total_runs = ($runnerRows | measure total_runs -Sum).Sum
  volunteer_credits = ($runnerRows | measure volunteer_credits -Sum).Sum
  shared_events = @($allEvents.Values | ? { $_ -eq $family.Count }).Count
  events_any = $allEvents.Count
  as_of = $asOf
  # upcoming parkrun days, comma-separated: the page counts along this for "parkruns I'll miss"
  run_dates = ($runDays | % { $_.ToString('yyyy-MM-dd') }) -join ','
}

# ---- what changed since the last build (for the weekly report)
$prevPath = Join-Path $dist 'runners.json'
$prevNendyPath = Join-Path $dist 'nendy.json'
$changes = @()
if (Test-Path $prevPath) {
  $prev = Read-Json $prevPath
  $prevNendy = if (Test-Path $prevNendyPath) { Read-Json $prevNendyPath } else { @() }
  foreach ($r in $runnerRows) {
    $p = $prev | ? { $_.runner_id -eq $r.runner_id }
    if (-not $p) { continue }
    $bits = @()
    $d = $r.total_runs - $p.total_runs; if ($d) { $bits += "+$d parkrun(s), now $($r.total_runs)" }
    $hit = $milestones.runs | ? { $_ -gt $p.total_runs -and $_ -le $r.total_runs } | select -Last 1
    if ($hit) { $bits += "reached the $hit milestone!" }
    $d = $r.volunteer_credits - $p.volunteer_credits; if ($d) { $bits += "+$d volunteer credit(s)" }
    $hit = $milestones.volunteer | ? { $_ -gt $p.volunteer_credits -and $_ -le $r.volunteer_credits } | select -Last 1
    if ($hit) { $bits += "reached the v$hit milestone!" }
    if ($r.raefarer_finished -ne $p.raefarer_finished) { $bits += "Raefarer x$($p.raefarer_finished) -> x$($r.raefarer_finished)" }
    elseif ($r.done_next -ne $p.done_next) { $bits += "round $($r.next_round): $($p.done_next) -> $($r.done_next) of $($r.raefarer_total)" }
    $n1 = ($nendy | ? { $_.key -eq $r.key -and $_.rank -eq 1 }).event
    $o1 = ($prevNendy | ? { $_.key -eq $r.key -and $_.rank -eq 1 }).event
    if ($o1 -and $n1 -ne $o1) { $bits += "NENDY $o1 -> $n1" }
    $changes += if ($bits) { "$($r.name): " + ($bits -join '; ') } else { "$($r.name): no change" }
  }
}

$latchOut = [ordered]@{}; foreach ($m in $family) { $latchOut[$m.key] = $latched[$m.key] }
[System.IO.File]::WriteAllText($latchPath, ($latchOut | ConvertTo-Json) + "`n", (New-Object System.Text.UTF8Encoding $false))

Save 'runners.json' $runnerRows
Save 'sydney_table.json' $table
Save 'combos.json' $combos
Save 'nendy.json' $nendy
Save 'family.json' @($familyRow)

# ---- page document
$html = [System.IO.File]::ReadAllText((Join-Path $root 'src\index.html'))
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$page = [ordered]@{ text = $html; edit = [ordered]@{ via = 'claude'; at = $stamp } } | ConvertTo-Json -Depth 3 -Compress
[System.IO.File]::WriteAllText((Join-Path $dist 'page.json'), $page, (New-Object System.Text.UTF8Encoding $false))
"page.json          $($html.Length) chars"

$runnerRows | ft name, total_runs, volunteer_credits, raefarer_finished, next_round, done_next -AutoSize | Out-String
if ($changes) { "CHANGES SINCE LAST BUILD"; $changes }

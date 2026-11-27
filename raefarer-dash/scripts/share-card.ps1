# Renders dist/share.png (1080x1350, for Messenger) from the built data, using headless Edge.
# Run after build.ps1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
function Read-Json($name) { @(([System.IO.File]::ReadAllText((Join-Path $dist $name)) | ConvertFrom-Json)) | % { $_ } }
function Esc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

$runners = Read-Json 'runners.json'
$nendy = Read-Json 'nendy.json'
$family = (Read-Json 'family.json')[0]
$top = Read-Json 'combos.json' | ? { $_.combo -eq 'judi+katie+mathew' } | sort rank | select -First 7
$colors = @{ judi = '#e8792b'; katie = '#3a7fd0'; mathew = '#3a9a52' }
$order = 'judi', 'katie', 'mathew'
$asOf = if ($family.results_to_text) { 'Results to ' + $family.results_to_text } else { ([datetime]$family.as_of).ToString('d MMM yyyy') }
$logo = [System.IO.File]::ReadAllText((Join-Path $root 'src\icon.svg'))

$cards = foreach ($k in $order) {
  $r = $runners | ? { $_.key -eq $k }
  $n = $nendy | ? { $_.key -eq $k -and $_.rank -eq 1 }
  $pct = [math]::Round(100 * $r.done_next / $r.raefarer_total)
@"
<div class="card" style="--c:$($colors[$k])">
  <div class="name">$(Esc $r.name)</div>
  <div class="lvl">Raefarer &times;$($r.raefarer_finished)</div>
  <div class="sub">Round $($r.next_round): $($r.done_next)/$($r.raefarer_total)</div>
  <div class="bar"><i style="width:$pct%"></i></div>
  <div class="row"><b>$($r.total_runs)</b> runs</div>
  <div class="row"><b>$($r.volunteer_credits)</b> vol</div>
  <div class="row">NENDY <b>$(Esc $n.event)</b></div>
</div>
"@
}

$list = foreach ($t in $top) {
  $dots = ($order | ? { $t."need_$_" -eq 1 } | % { "<i style='background:$($colors[$_])'></i>" }) -join ''
  "<li><span class='ev'>$(Esc $t.event)</span><span class='dots'>$dots</span><span class='mins'>$($t.drive_mins) min</span></li>"
}

$html = @"
<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1350px;background:#f2f1f5;color:#272727;font-family:"Montserrat","Segoe UI",system-ui,sans-serif}
.wrap{padding:56px 60px;display:flex;flex-direction:column;gap:40px;height:100%}
.hd{background:#2b233d;color:#fff;border-radius:10px;padding:36px 40px}
h1{font-weight:700;font-size:62px;letter-spacing:-.5px;display:flex;align-items:center;gap:22px}
.logo{display:block;width:78px;height:78px;margin-left:-10px}.logo svg{display:block;width:100%;height:100%}
.date{font-size:26px;color:#c9c3d6;margin-top:8px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:22px}
.card{background:#fff;border-radius:10px;border-top:10px solid var(--c);padding:26px 24px;display:flex;flex-direction:column;gap:10px;box-shadow:0 10px 24px rgba(43,35,61,.10)}
.name{font-size:34px;font-weight:700;color:var(--c)}
.lvl{font-weight:700;font-size:36px;white-space:nowrap}
.sub{font-size:24px;color:#666}
.bar{height:14px;border-radius:7px;background:#e7e5ee;overflow:hidden;margin-bottom:6px}
.bar i{display:block;height:100%;background:var(--c);border-radius:7px}
.row{font-size:25px;color:#45473f}
.row b{color:#1d1f1c}
h2{font-size:30px;font-weight:700;margin-bottom:16px}
ul{list-style:none;background:#fff;border-radius:10px;padding:8px 28px;box-shadow:0 10px 24px rgba(43,35,61,.10)}
li{display:flex;align-items:center;gap:16px;font-size:28px;padding:13px 0;border-bottom:1px solid #e9e7ef}
li:last-child{border-bottom:0}
.ev{flex:1}
.dots{display:flex;gap:6px}.dots i{width:18px;height:18px;border-radius:50%}
.mins{color:#666;font-size:26px;width:110px;text-align:right}
.foot{margin-top:auto;font-size:24px;color:#666}
</style></head><body><div class="wrap">
<div class="hd"><h1><span class="logo">$logo</span>parkrun HQ</h1><div class="date">$asOf</div></div>
<div class="cards">$($cards -join '')</div>
<div><h2>Next, all 3</h2><ul>$($list -join '')</ul></div>
<div class="foot">$($family.total_runs) family runs &middot; $($family.volunteer_credits) vol credits &middot; $($family.shared_events) shared events</div>
</div></body></html>
"@

$card = Join-Path $dist 'share-card.html'
[System.IO.File]::WriteAllText($card, $html, (New-Object System.Text.UTF8Encoding $false))
$png = Join-Path $dist 'share.png'
if (Test-Path $png) { Remove-Item $png }
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | ? { Test-Path $_ } | select -First 1
if (-not $edge) { throw 'Microsoft Edge not found' }
$profileDir = Join-Path $env:TEMP 'parkrun-dash-edge'
$p = Start-Process $edge -ArgumentList '--headless=new', '--disable-gpu', '--hide-scrollbars', '--virtual-time-budget=8000', "--user-data-dir=`"$profileDir`"", "--screenshot=`"$png`"", '--window-size=1080,1350', "`"file:///$($card -replace '\\','/')`"" -PassThru -Wait -WindowStyle Hidden
if (-not (Test-Path $png)) { throw "Edge didn't write $png" }
"share.png written: $png"

# Commits this week's runner files and the rebuilt public site, then pushes to GitHub
# (GitHub Pages serves docs/). Uses Git's saved sign-in; no token in this project.
# Run after site.ps1. -NoPush commits only (for checking before the first push).
param([switch]$NoPush)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = 'C:\Program Files\Git\cmd\git.exe' }
if (-not (Test-Path $git)) { Write-Warning 'git not found: site not published'; return }
function Git { & $git -C $repo @args; if ($LASTEXITCODE) { throw "git $($args -join ' ') failed ($LASTEXITCODE)" } }

Git pull --ff-only --quiet
Git add -A -- raefarer-dash docs .gitignore
$staged = & $git -C $repo diff --cached --name-only
if (-not $staged) { 'site: nothing changed, nothing to publish'; return }
Git commit --quiet -m "Weekly refresh $(Get-Date -Format 'yyyy-MM-dd')"
"committed: $(& $git -C $repo log -1 --format='%h %s') ($(@($staged).Count) files)"
if ($NoPush) { 'not pushed (-NoPush)'; return }
Git push --quiet
'site published: https://mathewgardiner.github.io/parkrun/raefarer-dash/'

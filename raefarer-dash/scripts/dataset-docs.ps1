# After uploading dist/*.json, writes one update document per dataset to dist/ds/<id>.json,
# pointing it at the new upload. Pass the asset ids the uploads returned, e.g.
#   scripts\dataset-docs.ps1 -runners 36ed... -sydney_table c87b... -combos c26e... -nendy 16be... -family bd65...
# Then apply them with one ArtifactData batch of 'update' ops using file_path (see REFRESH.md).
param(
  [Parameter(Mandatory)][string]$runners,
  [Parameter(Mandatory)][string]$sydney_table,
  [Parameter(Mandatory)][string]$combos,
  [Parameter(Mandatory)][string]$nendy,
  [Parameter(Mandatory)][string]$family
)
$ErrorActionPreference = 'Stop'
$out = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist\ds'
New-Item -ItemType Directory -Force $out | Out-Null
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$ids = [ordered]@{ runners = $runners; sydney_table = $sydney_table; combos = $combos; nendy = $nendy; family = $family }
foreach ($k in $ids.Keys) {
  $id = $ids[$k] -replace '^/?_blob/', ''
  if ($id -notmatch '^[0-9a-f]{32}$') { throw "$k : '$id' isn't an asset id" }
  $doc = [ordered]@{
    source  = [ordered]@{ url = "/_blob/$id" }
    updated = [ordered]@{ at = $now; by = 'Claude weekly refresh' }
    edit    = [ordered]@{ via = 'claude'; at = $now }
  }
  [System.IO.File]::WriteAllText((Join-Path $out "$k.json"), ($doc | ConvertTo-Json -Depth 3 -Compress), (New-Object System.Text.UTF8Encoding $false))
  "dist\ds\$k.json -> /_blob/$id"
}

<#
  TIMBANG: put the private files from a secrets-backup zip back where the build expects them.

  Usage (from the Timbang folder, after downloading the zip from Google Drive):
    powershell -ExecutionPolicy Bypass -File scripts\secrets-restore.ps1 -From "$env:USERPROFILE\Downloads\TIMBANG-SECRETS-20261108-173000.zip"

  Without -From it uses the newest TIMBANG-SECRETS-*.zip in Downloads or Documents\TIMBANG-SECRETS.
  An existing file that differs is kept as <name>.bak-<date> before it is replaced.
#>
param([string]$From)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$userHome = $env:USERPROFILE
$docs = [Environment]::GetFolderPath('MyDocuments')
if (-not $docs) { $docs = Join-Path $userHome 'Documents' }

if (-not $From) {
  $candidates = @(
    (Join-Path $userHome 'Downloads'),
    (Join-Path $docs 'TIMBANG-SECRETS')
  ) | Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ -Filter 'TIMBANG-SECRETS-*.zip' -ErrorAction SilentlyContinue }
  $latest = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { Write-Host "No TIMBANG-SECRETS-*.zip found. Pass -From <zip>." -ForegroundColor Red; exit 1 }
  $From = $latest.FullName
}
if (-not (Test-Path $From)) { Write-Host "Not found: $From" -ForegroundColor Red; exit 1 }

$work = Join-Path $env:TEMP ("timbang-restore-" + (Get-Date -Format 'yyyyMMddHHmmss'))
if ((Get-Item $From).PSIsContainer) { $work = $From } else { Expand-Archive -Path $From -DestinationPath $work -Force }
Write-Host "`nTIMBANG secrets restore from $From`n"

$targets = @{
  'google-services.json' = Join-Path $repo 'app\android\app\google-services.json'
  'debug.keystore'       = Join-Path $userHome '.android\debug.keystore'
  'timbang-sa.json'      = Join-Path $userHome 'keys\timbang-sa.json'
  'upload-keystore.jks'  = Join-Path $userHome 'keys\timbang-upload.jks'
  'key.properties'       = Join-Path $repo 'app\android\key.properties'
}

# Guard: refuse another project's Firebase file (e.g. One Vizcaya's).
$skip = @{}
$gs = Join-Path $work 'google-services.json'
if (Test-Path $gs) {
  $json = Get-Content $gs -Raw
  if ($json -notmatch '"project_id"\s*:\s*"timbang-nv"' -or $json -notmatch 'ph\.timbang\.timbang') {
    Write-Host "  STOP     google-services.json is not for timbang-nv / ph.timbang.timbang. Skipped." -ForegroundColor Red
    $skip['google-services.json'] = $true
  }
}

foreach ($name in $targets.Keys) {
  $src = Join-Path $work $name
  if ($skip[$name] -or -not (Test-Path $src)) { continue }
  $dst = $targets[$name]
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if (Test-Path $dst) {
    if ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) {
      Write-Host ("  same     {0,-22} {1}" -f $name, $dst); continue
    }
    $bak = "$dst.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Copy-Item $dst $bak
    Write-Host ("  kept old {0,-22} {1}" -f $name, $bak) -ForegroundColor Yellow
  }
  Copy-Item $src $dst -Force
  Write-Host ("  placed   {0,-22} {1}" -f $name, $dst) -ForegroundColor Green
}

$gradleSrc = Join-Path $work 'gradle'
if (Test-Path $gradleSrc) {
  $dists = Join-Path $userHome '.gradle\wrapper\dists'
  Get-ChildItem $gradleSrc -Recurse -File | ForEach-Object {
    $dst = Join-Path $dists $_.FullName.Substring($gradleSrc.Length + 1)
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Get-ChildItem (Split-Path $dst) -Filter '*.part' -ErrorAction SilentlyContinue | Remove-Item
    Get-ChildItem (Split-Path $dst) -Filter '*.lck' -ErrorAction SilentlyContinue | Remove-Item
    if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst; Write-Host "  placed   Gradle 9.3.1 download" -ForegroundColor Green }
    else { Write-Host "  same     Gradle 9.3.1 download" }
  }
}

$fp = Join-Path $work 'fingerprints.txt'
if (Test-Path $fp) { Write-Host "`nKey fingerprints (should match Firebase -> Project settings -> Android app):"; Get-Content $fp }
if ($work -ne $From) { Remove-Item $work -Recurse -Force }
Write-Host "`nDone. Next: cd app; flutter pub get; flutter build apk --release -t lib/main_app.dart" -ForegroundColor Cyan

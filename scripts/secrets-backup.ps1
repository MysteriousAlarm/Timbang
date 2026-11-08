<#
  TIMBANG: back up the private files that are NOT on GitHub, into one zip you keep on
  Google Drive (never in the repo). Restore later with scripts\secrets-restore.ps1.

  Usage (from the Timbang folder):
    powershell -ExecutionPolicy Bypass -File scripts\secrets-backup.ps1
    powershell -ExecutionPolicy Bypass -File scripts\secrets-backup.ps1 -IncludeGradle
    powershell -ExecutionPolicy Bypass -File scripts\secrets-backup.ps1 -Destination "G:\My Drive\TIMBANG-SECRETS"

  -IncludeGradle  also saves the Gradle 9.3.1 download (~230 MB), so a new PC does not
                  need GitHub to build.
  -Destination    where the zip goes (default: Documents\TIMBANG-SECRETS). With Google Drive
                  for desktop, point it at a Drive folder and it uploads by itself.
#>
param(
  [string]$Destination,
  [switch]$IncludeGradle
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$userHome = $env:USERPROFILE
$docs = [Environment]::GetFolderPath('MyDocuments')
if (-not $docs) { $docs = Join-Path $userHome 'Documents' }
if (-not $Destination) { $Destination = Join-Path $docs 'TIMBANG-SECRETS' }

# name in backup -> where it lives on this PC
$items = @(
  @{ Name = 'google-services.json'; Path = Join-Path $repo 'app\android\app\google-services.json'; Why = 'Android app <-> Firebase (timbang-nv)' },
  @{ Name = 'debug.keystore';       Path = Join-Path $userHome '.android\debug.keystore';          Why = 'Signs the APK; its SHA-1/SHA-256 are registered in Firebase' },
  @{ Name = 'timbang-sa.json';      Path = Join-Path $userHome 'keys\timbang-sa.json';             Why = 'Service-account key for npm run seed:admin' },
  @{ Name = 'upload-keystore.jks';  Path = Join-Path $userHome 'keys\timbang-upload.jks';          Why = 'Release signing key (only once it is set up)' },
  @{ Name = 'key.properties';       Path = Join-Path $repo 'app\android\key.properties';           Why = 'Passwords for the release key (only once it is set up)' }
)

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path $env:TEMP "timbang-secrets-$stamp"
New-Item -ItemType Directory -Force $work | Out-Null

Write-Host "`nTIMBANG secrets backup`n"
$saved = 0
foreach ($i in $items) {
  if (Test-Path $i.Path) {
    Copy-Item $i.Path (Join-Path $work $i.Name)
    Write-Host ("  saved    {0,-22} {1}" -f $i.Name, $i.Why) -ForegroundColor Green
    $saved++
  } else {
    Write-Host ("  missing  {0,-22} {1}" -f $i.Name, $i.Path) -ForegroundColor Yellow
  }
}

if ($IncludeGradle) {
  $dists = Join-Path $userHome '.gradle\wrapper\dists'
  $zip = Get-ChildItem $dists -Recurse -Filter 'gradle-9.3.1-all.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($zip) {
    $rel = $zip.FullName.Substring($dists.Length + 1)        # gradle-9.3.1-all\<hash>\gradle-9.3.1-all.zip
    $target = Join-Path $work (Join-Path 'gradle' $rel)
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item $zip.FullName $target
    Write-Host "  saved    Gradle 9.3.1 download" -ForegroundColor Green
  } else {
    Write-Host "  missing  Gradle 9.3.1 download (build once first)" -ForegroundColor Yellow
  }
}

# Fingerprints are not secret: kept next to the key so you can compare with Firebase.
$keystore = Join-Path $work 'debug.keystore'
if (Test-Path $keystore) {
  try {
    $out = & keytool -list -v -keystore $keystore -alias androiddebugkey -storepass android -keypass android 2>$null
    ($out | Select-String 'SHA1:|SHA256:' | ForEach-Object { $_.Line.Trim() }) | Set-Content (Join-Path $work 'fingerprints.txt')
  } catch { }
}
"Backed up $(Get-Date) from $env:COMPUTERNAME. Restore: scripts\secrets-restore.ps1 -From <this zip>" |
  Set-Content (Join-Path $work 'README.txt')

if ($saved -eq 0) { Write-Host "`nNothing to back up." -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Force $Destination | Out-Null
$zipPath = Join-Path $Destination "TIMBANG-SECRETS-$stamp.zip"
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zipPath
Remove-Item $work -Recurse -Force

Write-Host "`nDone: $zipPath" -ForegroundColor Cyan
Write-Host "Upload this zip to a PRIVATE Google Drive folder (e.g. timbang-secrets). Never put it in the repo."

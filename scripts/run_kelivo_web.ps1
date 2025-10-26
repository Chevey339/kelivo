param(
  [int]$Port = 5173
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Log {
  param([string]$Message)
  Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path $scriptRoot -Parent
$localSdkRoot = Join-Path $env:LOCALAPPDATA 'flutter-sdk'
$flutterBin = Join-Path $localSdkRoot 'flutter\bin'

function Ensure-Flutter {
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Log 'Flutter found on PATH'
    return
  }
  if (Test-Path (Join-Path $flutterBin 'flutter.bat')) {
    Write-Log 'Using local Flutter SDK in LOCALAPPDATA'
    $env:Path = $flutterBin + ';' + $env:Path
    return
  }

  Write-Log 'Flutter not found. Downloading stable SDK (local, user scope) ...'
  New-Item -ItemType Directory -Force -Path $localSdkRoot | Out-Null

  $mirrors = @(
    'https://storage.flutter-io.cn/flutter_infra_release/releases',
    'https://storage.googleapis.com/flutter_infra_release/releases'
  )

  $json = $null
  foreach ($base in $mirrors) {
    try {
      $jsonUrl = "$base/releases_windows.json"
      Write-Log "Fetching releases metadata: $jsonUrl"
      $json = Invoke-RestMethod -UseBasicParsing -Uri $jsonUrl
      if ($json) { break }
    } catch { }
  }
  if (-not $json) { throw 'Failed to fetch Flutter releases metadata from mirrors.' }

  $stable = $json.current_release.stable
  $entry = $json.releases | Where-Object { $_.hash -eq $stable -and $_.channel -eq 'stable' } | Select-Object -First 1
  if (-not $entry) { throw 'Failed to resolve Flutter stable release entry.' }

  $archiveRel = $entry.archive # e.g. windows/flutter_windows_3.x.x-stable.zip
  $downloaded = $false
  foreach ($base in $mirrors) {
    try {
      $url = "$base/$archiveRel"
      $zipPath = Join-Path $localSdkRoot 'flutter_windows_stable.zip'
      Write-Log "Downloading: $url"
      Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
      Write-Log 'Expanding SDK archive ...'
      Expand-Archive -Path $zipPath -DestinationPath $localSdkRoot -Force
      $downloaded = $true
      break
    } catch {
      Write-Log "Mirror failed, trying next..."
    }
  }
  if (-not $downloaded) { throw 'Failed to download Flutter SDK from all mirrors.' }

  $env:Path = $flutterBin + ';' + $env:Path
}

Write-Log '== Kelivo Web Runner =='
Write-Log "Project: $projectRoot"
Write-Log "Port: $Port"

Ensure-Flutter

$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
if (-not $env:PUB_HOSTED_URL) { $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn' }
if (-not $env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn' }

Write-Log 'Flutter version:'
flutter --version

Write-Log 'Enable web and precache web artifacts ...'
flutter config --enable-web --no-analytics
flutter precache --web

Write-Log 'Fetching dependencies (flutter pub get) ...'
Set-Location $projectRoot
flutter pub get

Write-Log 'Starting web-server (no auto browser) ...'
Write-Log "Open: http://127.0.0.1:$Port"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port



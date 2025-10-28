Param(
  [string]$Channel = 'stable',
  [string]$DestDir = '.flutter'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host $msg -ForegroundColor Gray }
function Write-Ok($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Err($msg) { Write-Host $msg -ForegroundColor Red }

try {
  # Ensure TLS 1.2 for downloads
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
  Set-Location $repoRoot

  function Get-ResolvedBase([string]$baseUrl) {
    $candidates = @(
      "$baseUrl/flutter_infra_release",
      "$baseUrl".TrimEnd('/')
    )
    foreach ($cb in $candidates) {
      $test = "$cb/releases/releases_windows.json"
      try {
        $head = Invoke-WebRequest -UseBasicParsing -Uri $test -Method Head -TimeoutSec 15
        if ($head.StatusCode -ge 200 -and $head.StatusCode -lt 300) { return @{ base = $cb; url = $test } }
      } catch { }
    }
    return $null
  }

  function Download-File([string]$url, [string]$dest) {
    Write-Info "Attempting BITS download..."
    try {
      Start-BitsTransfer -Source $url -Destination $dest -Description 'Downloading Flutter SDK' -ErrorAction Stop
      return $true
    } catch {
      Write-Info "BITS failed: $($_.Exception.Message). Falling back to Invoke-WebRequest."
    }
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $dest -TimeoutSec 600
      return $true
    } catch {
      Write-Info "Invoke-WebRequest failed: $($_.Exception.Message)"
      return $false
    }
  }

  $mirrorCandidates = @()
  if (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_STORAGE_BASE_URL)) { $mirrorCandidates += $env:FLUTTER_STORAGE_BASE_URL }
  $mirrorCandidates += @(
    'https://mirrors.tuna.tsinghua.edu.cn/flutter',
    'https://mirrors.ustc.edu.cn/flutter',
    'https://mirrors.cloud.tencent.com/flutter',
    'https://storage.googleapis.com/flutter_infra_release'
  )

  $resolvedBase = $null
  $releasesUrl = $null
  $meta = $null
  $temp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "flutter-setup-$(Get-Date -Format 'yyyyMMddHHmmss')")
  $jsonPath = Join-Path $temp.FullName 'releases_windows.json'
  foreach ($candidate in $mirrorCandidates) {
    Write-Section "Trying mirror: $candidate"
    $res = Get-ResolvedBase $candidate
    if (-not $res) { Write-Info 'Releases index not found on this mirror.'; continue }
    $resolvedBase = $res.base
    $releasesUrl = $res.url
    Write-Info "Fetching releases index: $releasesUrl"
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $releasesUrl -OutFile $jsonPath -TimeoutSec 60
      $meta = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
      break
    } catch {
      Write-Info "Failed to fetch releases from this mirror: $($_.Exception.Message)"
      $resolvedBase = $null; $releasesUrl = $null
    }
  }
  if (-not $meta) { throw 'Unable to fetch releases index from any mirror.' }

  $hash = $meta.current_release.$Channel
  if (-not $hash) { throw "Cannot determine current_release hash for channel '$Channel'" }
  $release = $meta.releases | Where-Object { $_.hash -eq $hash }
  if (-not $release) { $release = $meta.releases | Where-Object { $_.channel -eq $Channel -and $_.archive -match 'windows' } | Select-Object -First 1 }
  if (-not $release) { throw "No Windows release found for channel '$Channel'" }

  $archivePath = $release.archive
  if (-not $archivePath) { throw 'Release entry missing archive path' }
  $downloadUrl = "$resolvedBase/releases/$archivePath"
  Write-Section "Downloading Flutter SDK: $downloadUrl"

  $zipPath = Join-Path $temp.FullName (Split-Path -Leaf $archivePath)
  $dlOk = Download-File -url $downloadUrl -dest $zipPath
  if (-not $dlOk) {
    # Try remaining mirrors for the archive download
    foreach ($candidate in $mirrorCandidates) {
      if ($candidate -eq $env:FLUTTER_STORAGE_BASE_URL) { continue }
      $res = Get-ResolvedBase $candidate
      if (-not $res) { continue }
      $altUrl = "$($res.base)/releases/$archivePath"
      Write-Info "Retrying download from: $altUrl"
      $dlOk = Download-File -url $altUrl -dest $zipPath
      if ($dlOk) { break }
    }
  }
  if (-not $dlOk) { throw 'Failed to download Flutter SDK from all mirrors.' }

  if (Test-Path $DestDir) {
    Write-Info "Removing existing $DestDir"
    Remove-Item -Recurse -Force $DestDir
  }

  $extractRoot = Join-Path $temp.FullName 'extract'
  New-Item -ItemType Directory -Path $extractRoot | Out-Null
  Write-Info 'Expanding archive...'
  Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

  $sdkDir = Join-Path $extractRoot 'flutter'
  if (-not (Test-Path $sdkDir)) {
    throw 'Expanded SDK folder not found (expected subdir `flutter`)'
  }

  Move-Item -Path $sdkDir -Destination $DestDir
  Write-Ok "Flutter SDK is ready at: $DestDir"

  $flutterBin = (Resolve-Path (Join-Path $DestDir 'bin')).Path
  $env:PATH = "$flutterBin;" + $env:PATH
  Write-Section 'Flutter version'
  flutter --version | Out-Host

  Write-Section 'Flutter doctor'
  flutter doctor -v | Out-Host
}
catch {
  Write-Err $_
  exit 1
}

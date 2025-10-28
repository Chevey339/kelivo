Param(
  [switch]$Clean,
  [switch]$DisableTts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host $msg -ForegroundColor Gray }
function Write-Ok($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host $msg -ForegroundColor Red }

try {
  Write-Section 'Environment checks'
  $repoRoot = (Resolve-Path "$PSScriptRoot/..")

  function Add-FlutterToPathFrom($binDir) {
    if ($binDir -and (Test-Path $binDir)) { $env:PATH = "$binDir;" + $env:PATH }
  }

  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # 1) Try .flutter
    $candidate = Join-Path $repoRoot '.flutter/bin'
    if (Test-Path (Join-Path $candidate 'flutter.bat')) { Add-FlutterToPathFrom $candidate }
  }
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # 2) Try ./flutter
    $candidate = Join-Path $repoRoot 'flutter/bin'
    if (Test-Path (Join-Path $candidate 'flutter.bat')) { Add-FlutterToPathFrom $candidate }
  }
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # 3) Search recursively for any *\bin\flutter.bat under repo
    $bat = Get-ChildItem -Path $repoRoot -Recurse -Filter 'flutter.bat' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match "\\bin\\flutter\.bat$" } |
      Select-Object -First 1
    if ($bat) {
      Add-FlutterToPathFrom ($bat.Directory.FullName)
      Write-Info ("Using Flutter from: " + $bat.Directory.FullName)
    }
  }
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter CLI not found. Add Flutter to PATH or place SDK under this repo (any folder containing bin\flutter.bat).'
  }
  flutter --version | Out-Host

  Write-Section 'Enable Windows desktop'
  flutter config --enable-windows-desktop | Out-Host

  if ($Clean) {
    Write-Section 'Cleaning build'
    flutter clean | Out-Host
  }

  # Back up pubspec in case we need to temporarily modify it
  $pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
  $pubspecRaw = Get-Content -Path $pubspecPath -Raw -Encoding UTF8
  $pubspecTempChanged = $false

  Write-Section 'Fetching dependencies'
  flutter pub get | Out-Host

  if ($DisableTts) {
    Write-Section 'Temporarily disabling flutter_tts for Windows'
    $modified = $false
    $lines = $pubspecRaw -split "`n"
    $new = foreach ($l in $lines) {
      if ($l -match '^\s+flutter_tts:') { $modified = $true; "  # $l  # Disabled for Windows build" } else { $l }
    }
    if ($modified) {
      $pubspecTempChanged = $true
      ($new -join "`n") | Set-Content -Path $pubspecPath -NoNewline -Encoding UTF8
      Write-Info 'Re-running flutter pub get after modifying pubspec.yaml'
      flutter pub get | Out-Host
    } else {
      Write-Info 'No flutter_tts entry found to disable.'
    }
  }

  Write-Section 'Selecting CMake generator'
  $vs2022 = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
  $vs2019 = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools'
  $picked = $null
  if (Test-Path $vs2022) {
    $cl2022 = Get-ChildItem -Path $vs2022 -Recurse -Filter 'cl.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cl2022) {
      $env:CMAKE_GENERATOR = 'Visual Studio 17 2022'
      $env:CMAKE_GENERATOR_TOOLSET = 'v143'
      $env:CMAKE_GENERATOR_INSTANCE = $vs2022
      $picked = 'VS2022 BuildTools'
    }
  }
  if (-not $picked -and (Test-Path $vs2019)) {
    $cl2019 = Get-ChildItem -Path $vs2019 -Recurse -Filter 'cl.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cl2019) {
      $env:CMAKE_GENERATOR = 'Visual Studio 16 2019'
      $env:CMAKE_GENERATOR_TOOLSET = 'v142'
      $env:CMAKE_GENERATOR_INSTANCE = $vs2019
      # Help older CMake locate VS2019 Build Tools
      $vsTools = Join-Path $vs2019 'Common7\Tools'
      if (Test-Path $vsTools) { $env:VS160COMNTOOLS = $vsTools }
      $vcDir = Join-Path $vs2019 'VC'
      if (Test-Path $vcDir) { $env:VCINSTALLDIR = $vcDir }
      $picked = 'VS2019 BuildTools'
    }
  }
  if ($picked) {
    Write-Info "Using generator: $($env:CMAKE_GENERATOR) ($picked)"
    Write-Info "Instance: $($env:CMAKE_GENERATOR_INSTANCE)"
  } else {
    Write-Warn 'Could not locate MSVC toolchain (cl.exe). CMake will auto-detect; if it fails, install VS2022 Build Tools with C++ workload.'
  }

  Write-Section 'Selecting CMake generator'
  $vs2022 = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools'
  $vs2019 = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools'
  $picked = $null
  if (Test-Path $vs2022) {
    $env:CMAKE_GENERATOR = 'Visual Studio 17 2022'
    $env:CMAKE_GENERATOR_TOOLSET = 'v143'
    $env:CMAKE_GENERATOR_INSTANCE = $vs2022
    $picked = 'VS2022 BuildTools'
  }
  if (-not $picked -and (Test-Path $vs2019)) {
    $env:CMAKE_GENERATOR = 'Visual Studio 16 2019'
    $env:CMAKE_GENERATOR_TOOLSET = 'v142'
    $env:CMAKE_GENERATOR_INSTANCE = $vs2019
    $vsTools = Join-Path $vs2019 'Common7\Tools'
    if (Test-Path $vsTools) { $env:VS160COMNTOOLS = $vsTools }
    $vcDir = Join-Path $vs2019 'VC'
    if (Test-Path $vcDir) { $env:VCINSTALLDIR = $vcDir }
    $picked = 'VS2019 BuildTools'
  }
  if ($picked) {
    Write-Info "Using generator: $($env:CMAKE_GENERATOR) ($picked)"
    Write-Info "Instance: $($env:CMAKE_GENERATOR_INSTANCE)"
  } else {
    Write-Warn 'No known MSVC instance found; CMake will try auto-detect.'
  }

  # Clear old CMake cache if generator changed between runs
  $cache = Join-Path $repoRoot 'build/windows/x64/CMakeCache.txt'
  if (Test-Path $cache) {
    Write-Info 'Removing old CMake cache to avoid generator mismatch'
    Remove-Item -Force $cache -ErrorAction SilentlyContinue
  }

  Write-Section 'Building Windows (release)'
  flutter build windows --release | Out-Host

  Write-Section 'Preparing portable package'
  $buildDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
  if (-not (Test-Path $buildDir)) {
    Write-Warn "Default build path not found: $buildDir"
    Write-Info 'Searching for built .exe under build\windows...'
    $exe = Get-ChildItem -Path (Join-Path $repoRoot 'build/windows') -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) { throw 'No executable produced. Check build logs above.' }
    $buildDir = $exe.Directory.FullName
    Write-Info "Using discovered build folder: $buildDir"
  }

  $distRoot = Join-Path $repoRoot 'dist'
  if (-not (Test-Path $distRoot)) { New-Item -ItemType Directory -Path $distRoot | Out-Null }
  $outDir = Join-Path $distRoot 'kelivo-windows-x64'
  if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
  New-Item -ItemType Directory -Path $outDir | Out-Null

  Write-Info "Copying runtime files to $outDir"
  Copy-Item -Path (Join-Path $buildDir '*') -Destination $outDir -Recurse -Force

  $zipPath = Join-Path $distRoot 'kelivo-windows-x64.zip'
  if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
  Write-Info "Creating archive: $zipPath"
  Compress-Archive -Path $outDir -DestinationPath $zipPath -Force

  $sizeMB = [Math]::Round((Get-Item $zipPath).Length / 1MB, 2)
  Write-Ok "Done: $zipPath (${sizeMB} MB)"
}
catch {
  Write-Err $_
  exit 1
}

finally {
  if ($pubspecTempChanged) {
    Write-Section 'Restoring original pubspec.yaml'
    $pubspecRaw | Set-Content -Path $pubspecPath -NoNewline -Encoding UTF8
    Write-Ok 'pubspec.yaml restored.'
  }
}

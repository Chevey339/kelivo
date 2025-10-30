@echo off
echo ========================================
echo Windows Build Test Script
echo ========================================
echo.

echo [1/6] Checking Flutter environment...
flutter doctor -v
if %errorlevel% neq 0 (
    echo ERROR: Flutter doctor failed
    pause
    exit /b 1
)
echo.

echo [2/6] Cleaning old builds...
flutter clean
if exist build rmdir /s /q build
echo.

echo [3/6] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo [4/6] Generating required files...
flutter pub run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo WARNING: Build runner had issues, but continuing...
)
echo.

echo [5/6] Disabling flutter_tts for Windows...
powershell -Command "$content = Get-Content pubspec.yaml -Raw; $content = $content -replace '(\s+flutter_tts:\s+\^[\d\.]+)', '  # $1  # Disabled for Windows'; Set-Content pubspec.yaml $content"
flutter pub get
echo.

echo [6/6] Building Windows application...
flutter build windows --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)
echo.

echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Build output location:
dir /s /b build\windows\x64\runner\Release\*.exe
echo.

echo Restoring pubspec.yaml...
git checkout pubspec.yaml
flutter pub get

pause


@echo off
REM Simple Windows build script for Kelivo
REM This script builds the Windows application with default settings

echo ========================================
echo Building Kelivo for Windows
echo ========================================
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "scripts\build_windows.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Build completed successfully!
    echo ========================================
    echo.
    echo Output files:
    echo   - Executable: build\windows\x64\runner\Release\kelivo.exe
    echo   - Portable:   dist\kelivo-windows-x64\
    echo   - Package:    dist\kelivo-windows-x64.zip
    echo.
    echo You can now run the application or distribute the ZIP file.
    echo.
) else (
    echo.
    echo ========================================
    echo Build failed! Check the error messages above.
    echo ========================================
    echo.
)

pause


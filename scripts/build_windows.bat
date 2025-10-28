@echo off
setlocal
set SCRIPT_DIR=%~dp0
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_windows.ps1" %*
endlocal


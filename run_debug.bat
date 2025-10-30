@echo off
echo ========================================
echo Starting Kelivo in Debug Mode
echo You will see all logs in this window
echo ========================================
echo.

cd /d "%~dp0"
.\flutter\bin\flutter.bat run -d windows --debug

pause

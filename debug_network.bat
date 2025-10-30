@echo off
cls
echo.
echo ========================================
echo   Kelivo Network Debug Tool
echo ========================================
echo.
echo Select debug method:
echo.
echo [1] DevTools Network Monitor (Recommended)
echo [2] Fiddler Capture (Need Fiddler installed)
echo [3] Terminal Log Mode
echo [4] Proxy Configuration Help
echo [0] Exit
echo.
set /p choice="Enter option (0-4): "

if "%choice%"=="1" goto devtools
if "%choice%"=="2" goto fiddler
if "%choice%"=="3" goto terminal
if "%choice%"=="4" goto proxy_help
if "%choice%"=="0" goto end
goto invalid

:devtools
cls
echo.
echo ========================================
echo   DevTools Network Monitor
echo ========================================
echo.
echo Starting application...
echo.
echo Instructions:
echo   1. Wait for app to start
echo   2. Terminal will show DevTools URL
echo   3. Open the URL in browser
echo   4. Click "Network" tab
echo   5. Use the app, all network requests will be shown
echo.
echo ========================================
echo.
cd /d "%~dp0"
.\flutter\bin\flutter.bat run -d windows --debug
goto end

:fiddler
cls
echo.
echo ========================================
echo   Fiddler Capture Mode
echo ========================================
echo.
echo Preparation Steps:
echo.
echo 1. Install Fiddler Classic
echo    Download: https://www.telerik.com/fiddler/fiddler-classic
echo.
echo 2. Start Fiddler
echo.
echo 3. Configure Fiddler HTTPS:
echo    - Tools - Options - HTTPS
echo    - Enable: Capture HTTPS CONNECTs
echo    - Enable: Decrypt HTTPS traffic
echo    - Actions - Trust Root Certificate
echo.
echo 4. Configure proxy in app:
echo    - Open app settings
echo    - Find Provider config
echo    - Enable proxy:
echo      * Host: 127.0.0.1
echo      * Port: 8888
echo.
echo ========================================
echo.
set /p ready="Ready? (y/n): "
if /i "%ready%"=="y" (
    echo.
    echo Starting application...
    echo.
    cd /d "%~dp0"
    .\flutter\bin\flutter.bat run -d windows
) else (
    echo.
    echo Cancelled
    pause
)
goto end

:terminal
cls
echo.
echo ========================================
echo   Terminal Log Mode
echo ========================================
echo.
echo Starting application with verbose logging...
echo.
echo Tips:
echo   - All network requests will show in terminal
echo   - Includes URL, headers, response, etc.
echo   - Log format: [HTTP] prefix
echo.
echo ========================================
echo.
cd /d "%~dp0"
.\flutter\bin\flutter.bat run -d windows -v
goto end

:proxy_help
cls
echo.
echo ========================================
echo   Proxy Configuration Guide
echo ========================================
echo.
echo How to configure proxy in app:
echo.
echo 1. Start the application
echo.
echo 2. Open Settings page
echo.
echo 3. Find "Provider Config" or "Model Config"
echo.
echo 4. Find proxy settings:
echo    - Enable Proxy: Check to enable
echo    - Proxy Host: 127.0.0.1
echo    - Proxy Port: 8888 (Fiddler) or 9090 (Proxyman)
echo    - Username: (optional)
echo    - Password: (optional)
echo.
echo 5. Save configuration
echo.
echo 6. Now all requests from this Provider will go through proxy
echo.
echo ========================================
echo.
echo Common capture tools:
echo.
echo   Fiddler Classic (Windows)
echo   - Free
echo   - Port: 8888
echo   - Download: https://www.telerik.com/fiddler/fiddler-classic
echo.
echo   Proxyman (Windows/Mac)
echo   - Free version limited
echo   - Port: 9090
echo   - Download: https://proxyman.io/
echo.
echo   Charles Proxy
echo   - Paid
echo   - Port: 8888
echo   - Download: https://www.charlesproxy.com/
echo.
echo ========================================
echo.
pause
cls
goto :eof

:invalid
cls
echo.
echo Invalid option!
echo.
pause
cls
goto :eof

:end


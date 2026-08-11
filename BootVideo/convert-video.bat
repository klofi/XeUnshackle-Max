@echo off
setlocal

:: ============================================================================
:: Boot video converter for XeUnshackle Max
:: ============================================================================
:: Drag a video file onto this script, or run it as:
::     convert-video.bat "C:\path\to\video.mp4"
::
:: It writes XeUnshackleVideo.wmv next to the source video, encoded in the
:: format the console can play. See BOOT_VIDEO.md for what to do with it,
:: and convert-video.ps1 for the options this wrapper does not expose.
:: ============================================================================

if "%~1"=="" (
    echo ERROR: No video given.
    echo.
    echo Drag a video file onto this script, or run:
    echo     convert-video.bat "C:\path\to\video.mp4"
    echo.
    pause
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0convert-video.ps1" -InputPath "%~1"
set "EXITCODE=%ERRORLEVEL%"

echo.
pause
exit /b %EXITCODE%

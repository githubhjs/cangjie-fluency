@echo off
rem Double-click to install cangjie5_fluency for Weasel. Runs install.ps1 next to this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause

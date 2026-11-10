@echo off
rem Double-click to install cangjie5_fluency for Weasel. Runs install.ps1 next to this file.
rem PSModulePath is cleared so Windows PowerShell 5.1 does not inherit PowerShell 7 module folders
rem when this file is started from a pwsh window (that broke Get-FileHash on the second run).
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause

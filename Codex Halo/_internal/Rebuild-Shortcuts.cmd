@echo off
set "SCRIPT=%~dp0Rebuild-Shortcuts.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
pause

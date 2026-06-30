@echo off
setlocal

set "ROOT=%~dp0"
set "SCRIPT=%ROOT%_internal\Rebuild-Shortcuts.ps1"

if not exist "%SCRIPT%" (
    echo Could not find: %SCRIPT%
    echo Make sure this file is in the Codex Halo folder root.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo Codex Halo shortcuts have been rebuilt for this computer.
echo You can now use the Start, Stop, and Move shortcuts in this folder.
pause

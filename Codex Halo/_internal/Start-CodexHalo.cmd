@echo off
set "SCRIPT=%~dp0Start-CodexHalo.ps1"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& '%SCRIPT%'"

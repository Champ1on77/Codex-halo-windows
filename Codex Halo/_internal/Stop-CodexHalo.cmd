@echo off
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$stop=Join-Path $env:TEMP 'codex-halo-stop.txt'; Set-Content -LiteralPath $stop -Value 'stop' -Encoding ASCII; Start-Sleep -Seconds 2; Get-Process codex-halo -ErrorAction SilentlyContinue | Stop-Process -Force"

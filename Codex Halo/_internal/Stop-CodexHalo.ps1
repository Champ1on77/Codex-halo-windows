$ErrorActionPreference = 'SilentlyContinue'

$stopFile = Join-Path $env:TEMP 'codex-halo-stop.txt'
$pidFile = Join-Path $env:TEMP 'codex-halo-monitor.pid'

Set-Content -LiteralPath $stopFile -Value 'stop' -Encoding ASCII
Start-Sleep -Milliseconds 2500

$pidText = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1
$monitorPid = 0
if ([int]::TryParse($pidText, [ref]$monitorPid)) {
    if ($monitorPid -gt 0 -and $monitorPid -ne $PID) {
        Get-Process -Id $monitorPid -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

Get-Process -Name 'codex-halo' -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue

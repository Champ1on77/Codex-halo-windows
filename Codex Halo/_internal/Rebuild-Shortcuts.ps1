$ErrorActionPreference = 'Stop'

$internal = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $internal
$exe = Join-Path $internal 'codex-halo.exe'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$wsh = New-Object -ComObject WScript.Shell
$startName = [string]::Concat([char]0x542F, [char]0x52A8, ' Codex Halo.lnk')
$stopName = [string]::Concat([char]0x505C, [char]0x6B62, ' Codex Halo.lnk')
$moveName = [string]::Concat([char]0x79FB, [char]0x52A8, ' Codex Halo.lnk')

$shortcuts = @(
    @{ Name = $startName; Target = 'Start-CodexHalo.ps1' },
    @{ Name = $stopName; Target = 'Stop-CodexHalo.ps1' },
    @{ Name = $moveName; Target = 'Move-CodexHalo.ps1' }
)

Get-ChildItem -LiteralPath $base -Filter '*Codex Halo.lnk' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

foreach ($item in $shortcuts) {
    $shortcutPath = Join-Path $base $item.Name
    $targetPath = Join-Path $internal $item.Target
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetPath`""
    $shortcut.WorkingDirectory = $internal
    $shortcut.WindowStyle = 7
    if (Test-Path -LiteralPath $exe) {
        $shortcut.IconLocation = "$exe,0"
    }
    $shortcut.Save()
}

Write-Host "Shortcuts rebuilt in: $base"

$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root 'codex-halo.exe'
$positionFile = Join-Path $root 'position.txt'
$stateFile = Join-Path $env:TEMP 'codex-halo-state2.txt'
$stopFile = Join-Path $env:TEMP 'codex-halo-stop.txt'
$pidFile = Join-Path $env:TEMP 'codex-halo-monitor.pid'
$sessionsRoot = Join-Path $env:USERPROFILE '.codex\sessions'

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CodexHaloStartWin32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\CodexHaloMonitor', [ref]$created)
if (-not $created) {
    exit 0
}

try {
    $lastState = ''
    $lastCompletedAt = $null
    $sessionFile = $null
    $sessionPosition = 0L
    $lastSessionSearch = [DateTime]::MinValue
    $searchIntervalMs = 1500
    $idleAfterCompletedMs = 2200
    $positionApplied = $false

    Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($pidFile, [string]$PID, [System.Text.UTF8Encoding]::new($false))

    function Write-HaloState {
        param([string]$State)

        if ($script:lastState -eq $State) {
            return
        }

        $tmp = "$script:stateFile.tmp"
        [System.IO.File]::WriteAllText($tmp, $State, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $script:stateFile -Force
        $script:lastState = $State
    }

    function Start-HaloProcess {
        if (-not (Test-Path -LiteralPath $script:exe)) {
            return
        }

        $shell = New-Object -ComObject Shell.Application
        $shell.ShellExecute($script:exe, '', $script:root, 'open', 1) | Out-Null
    }

    function Get-HaloWindowHandle {
        $haloProcesses = @(Get-Process -Name 'codex-halo' -ErrorAction SilentlyContinue)

        foreach ($process in ($haloProcesses | Where-Object { $_.MainWindowHandle -ne 0 })) {
            return [IntPtr]$process.MainWindowHandle
        }

        if ($haloProcesses.Count -eq 0) {
            return [IntPtr]::Zero
        }

        $pids = @($haloProcesses | Select-Object -ExpandProperty Id)
        $handles = New-Object 'System.Collections.Generic.List[IntPtr]'
        [CodexHaloStartWin32]::EnumWindows({
            param([IntPtr]$hWnd, [IntPtr]$lParam)

            [uint32]$pid = 0
            [void][CodexHaloStartWin32]::GetWindowThreadProcessId($hWnd, [ref]$pid)
            if (($pids -contains [int]$pid) -and [CodexHaloStartWin32]::IsWindowVisible($hWnd)) {
                $handles.Add($hWnd)
            }

            return $true
        }, [IntPtr]::Zero) | Out-Null

        if ($handles.Count -gt 0) {
            return $handles[0]
        }

        return [IntPtr]::Zero
    }

    function Apply-SavedHaloPosition {
        if (-not (Test-Path -LiteralPath $script:positionFile)) {
            return $false
        }

        $content = Get-Content -LiteralPath $script:positionFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($content -notmatch '^\s*(-?\d+)\s*,\s*(-?\d+)\s*$') {
            return $false
        }

        $x = [int]$matches[1]
        $y = [int]$matches[2]
        $deadline = (Get-Date).AddSeconds(5)

        while ((Get-Date) -lt $deadline) {
            $hWnd = Get-HaloWindowHandle
            if ($hWnd -ne [IntPtr]::Zero) {
                [void][CodexHaloStartWin32]::SetWindowPos($hWnd, [IntPtr](-1), $x, $y, 0, 0, 0x0051)
                return $true
            }

            Start-Sleep -Milliseconds 150
        }

        return $false
    }

    function Get-LatestSessionFile {
        if (-not (Test-Path -LiteralPath $script:sessionsRoot)) {
            return $null
        }

        Get-ChildItem -LiteralPath $script:sessionsRoot -Recurse -File -Filter '*.jsonl' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    function Get-StateFromSessionLine {
        param([string]$Line)

        if ([string]::IsNullOrWhiteSpace($Line)) {
            return $null
        }

        if ($Line -match '"type":"event_msg"' -and $Line -match '"type":"task_started"') {
            return 'thinking'
        }

        if ($Line -match '"type":"function_call"') {
            return 'executing'
        }

        if ($Line -match '"type":"function_call_output"') {
            return 'thinking'
        }

        if ($Line -match '"type":"event_msg"' -and $Line -match '"type":"task_complete"') {
            return 'completed'
        }

        return $null
    }

    function Get-StateFromSessionTail {
        param([string]$Path)

        if (-not (Test-Path -LiteralPath $Path)) {
            return 'idle'
        }

        $state = 'idle'
        $lines = Get-Content -LiteralPath $Path -Tail 250
        foreach ($line in $lines) {
            $lineState = Get-StateFromSessionLine $line
            if ($null -ne $lineState) {
                $state = $lineState
            }
        }

        if ($state -eq 'completed') {
            return 'idle'
        }

        return $state
    }

    function Read-NewSessionText {
        param(
            [string]$Path,
            [long]$Position
        )

        if (-not (Test-Path -LiteralPath $Path)) {
            return @{ Text = ''; Position = 0L }
        }

        $stream = $null
        $reader = $null
        try {
            $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            if ($Position -gt $stream.Length) {
                $Position = 0L
            }

            $stream.Seek($Position, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true, 4096, $true)
            $text = $reader.ReadToEnd()
            $newPosition = $stream.Position
            return @{ Text = $text; Position = $newPosition }
        }
        finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            }
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }

    Write-HaloState 'idle'

    while ($true) {
        if (Test-Path -LiteralPath $stopFile) {
            Write-HaloState 'completed'
            Start-Sleep -Seconds 1
            break
        }

        if (-not (Get-Process -Name 'codex-halo' -ErrorAction SilentlyContinue)) {
            Start-HaloProcess
            $positionApplied = $false
        }

        if (-not $positionApplied) {
            $positionApplied = Apply-SavedHaloPosition
        }

        $now = Get-Date
        if ((($now - $lastSessionSearch).TotalMilliseconds -ge $searchIntervalMs) -or $null -eq $sessionFile) {
            $latest = Get-LatestSessionFile
            $lastSessionSearch = $now

            if ($null -ne $latest -and ($null -eq $sessionFile -or $latest.FullName -ne $sessionFile)) {
                $sessionFile = $latest.FullName
                $startupState = Get-StateFromSessionTail $sessionFile
                Write-HaloState $startupState
                $sessionPosition = $latest.Length
            }
        }

        if ($null -ne $sessionFile) {
            $read = Read-NewSessionText -Path $sessionFile -Position $sessionPosition
            $sessionPosition = [long]$read.Position

            if (-not [string]::IsNullOrEmpty($read.Text)) {
                $lines = $read.Text -split "`r?`n"
                foreach ($line in $lines) {
                    $lineState = Get-StateFromSessionLine $line
                    if ($null -eq $lineState) {
                        continue
                    }

                    if ($lineState -eq 'completed') {
                        Write-HaloState 'completed'
                        $lastCompletedAt = Get-Date
                    } else {
                        $lastCompletedAt = $null
                        Write-HaloState $lineState
                    }
                }
            }
        }

        if ($lastState -eq 'completed' -and $null -ne $lastCompletedAt) {
            if (((Get-Date) - $lastCompletedAt).TotalMilliseconds -ge $idleAfterCompletedMs) {
                $lastCompletedAt = $null
                Write-HaloState 'idle'
            }
        }

        Start-Sleep -Milliseconds 350
    }
}
finally {
    if ($created) {
        $mutex.ReleaseMutex() | Out-Null
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    $mutex.Dispose()
}

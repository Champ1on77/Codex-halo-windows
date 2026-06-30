param(
    [switch]$Probe
)

$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root 'codex-halo.exe'
$positionFile = Join-Path $root 'position.txt'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CodexHaloMoveWin32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

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
    [CodexHaloMoveWin32]::EnumWindows({
        param([IntPtr]$hWnd, [IntPtr]$lParam)

        [uint32]$pid = 0
        [void][CodexHaloMoveWin32]::GetWindowThreadProcessId($hWnd, [ref]$pid)
        if (($pids -contains [int]$pid) -and [CodexHaloMoveWin32]::IsWindowVisible($hWnd)) {
            $handles.Add($hWnd)
        }

        return $true
    }, [IntPtr]::Zero) | Out-Null

    if ($handles.Count -gt 0) {
        return $handles[0]
    }

    return [IntPtr]::Zero
}

function Wait-HaloWindow {
    $deadline = (Get-Date).AddSeconds(8)

    while ((Get-Date) -lt $deadline) {
        $hWnd = Get-HaloWindowHandle
        if ($hWnd -ne [IntPtr]::Zero) {
            return $hWnd
        }

        Start-Sleep -Milliseconds 150
    }

    return [IntPtr]::Zero
}

function Start-HaloProcess {
    if (-not (Test-Path -LiteralPath $script:exe)) {
        return
    }

    $shell = New-Object -ComObject Shell.Application
    $shell.ShellExecute($script:exe, '', $script:root, 'open', 1) | Out-Null
}

if (-not (Get-Process -Name 'codex-halo' -ErrorAction SilentlyContinue)) {
    Start-HaloProcess
}

$hWnd = Wait-HaloWindow
if ($hWnd -eq [IntPtr]::Zero) {
    [System.Windows.Forms.MessageBox]::Show('Codex Halo window was not found. Start Codex Halo, then try again.', 'Codex Halo') | Out-Null
    exit 1
}

if ($Probe) {
    Write-Output "Halo window handle: $($hWnd.ToInt64())"
    exit 0
}

$rect = New-Object CodexHaloMoveWin32+RECT
[void][CodexHaloMoveWin32]::GetWindowRect($hWnd, [ref]$rect)
$haloWidth = [Math]::Max(80, $rect.Right - $rect.Left)
$haloHeight = [Math]::Max(80, $rect.Bottom - $rect.Top)
$savedX = $rect.Left
$savedY = $rect.Top
$dragging = $false
$moved = $false

$bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Move Codex Halo'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Bounds = $bounds
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::Black
$form.Opacity = 0.22
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::SizeAll

$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $false
$label.Width = 560
$label.Height = 80
$label.Left = [Math]::Max(20, $bounds.Left + [Math]::Floor(($bounds.Width - $label.Width) / 2))
$label.Top = [Math]::Max(20, $bounds.Top + 40)
$label.ForeColor = [System.Drawing.Color]::White
$label.BackColor = [System.Drawing.Color]::Transparent
$label.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Regular)
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$label.Text = "Hold the left mouse button and drag Codex Halo. Release to save. Press Esc to cancel."
$form.Controls.Add($label)

$moveHalo = {
    $point = [System.Windows.Forms.Cursor]::Position
    $script:savedX = $point.X - [Math]::Floor($script:haloWidth / 2)
    $script:savedY = $point.Y - [Math]::Floor($script:haloHeight / 2)
    [void][CodexHaloMoveWin32]::SetWindowPos($script:hWnd, [IntPtr](-1), $script:savedX, $script:savedY, 0, 0, 0x0051)
}

$form.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:moved = $true
        & $moveHalo
    }
})

$form.Add_MouseMove({
    if ($script:dragging) {
        & $moveHalo
    }
})

$form.Add_MouseUp({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $script:dragging) {
        $script:dragging = $false
        [System.IO.File]::WriteAllText($script:positionFile, "$script:savedX,$script:savedY", [System.Text.UTF8Encoding]::new($false))
        $form.Close()
    }
})

$form.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $form.Close()
    }
})

[void]$form.ShowDialog()

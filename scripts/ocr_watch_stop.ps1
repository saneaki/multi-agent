<#
.SYNOPSIS
  cmd_721 Pattern B: stop the OCR watchdog daemon on Windows.

.DESCRIPTION
  Reads the PID file written by ocr_watch_start.ps1 and stops the process
  gracefully (CloseMainWindow + WaitForExit). Falls back to Stop-Process
  if the process does not exit in time. As a last resort, scans for any
  python.exe running ocr_watch.py and stops them.

.PARAMETER LogDir
  Folder where the PID file was placed. Default: $env:LOCALAPPDATA\ocr_watch

.PARAMETER Force
  Use Stop-Process -Force instead of polite shutdown.

.PARAMETER RemoveStartup
  Remove the startup shortcut installed by ocr_watch_start.ps1 -InstallStartup.

.EXAMPLE
  PS> .\scripts\ocr_watch_stop.ps1

.EXAMPLE
  PS> .\scripts\ocr_watch_stop.ps1 -Force -RemoveStartup
#>

[CmdletBinding()]
param(
    [string] $LogDir = (Join-Path $env:LOCALAPPDATA "ocr_watch"),
    [switch] $Force,
    [switch] $RemoveStartup
)

$ErrorActionPreference = "Stop"

$pidFile = Join-Path $LogDir "ocr_watch.pid"
$stoppedCount = 0

# --- Stop by PID file --------------------------------------------------------

if (Test-Path -LiteralPath $pidFile) {
    $procId = (Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if ($procId -match '^\d+$') {
        try {
            $proc = Get-Process -Id ([int]$procId) -ErrorAction Stop
            Write-Host "Stopping PID $procId ..."
            if ($Force) {
                Stop-Process -Id $proc.Id -Force
            } else {
                $null = $proc.CloseMainWindow()
                if (-not $proc.WaitForExit(5000)) {
                    Write-Warning "Process did not exit; forcing"
                    Stop-Process -Id $proc.Id -Force
                }
            }
            $stoppedCount++
        } catch {
            Write-Warning "PID $procId not running (already stopped?): $($_.Exception.Message)"
        }
    } else {
        Write-Warning "PID file content not numeric; ignoring: $pidFile"
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Warning "PID file not found: $pidFile (using fallback scan)"
}

# --- Fallback: scan for stray ocr_watch.py processes -------------------------

try {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'" -ErrorAction Stop
} catch {
    $procs = @()
    Write-Warning "Could not query Win32_Process: $($_.Exception.Message)"
}

foreach ($p in $procs) {
    $cmdLine = $p.CommandLine
    if ($cmdLine -and $cmdLine -match 'ocr_watch\.py') {
        Write-Host "Stopping stray PID $($p.ProcessId): $cmdLine"
        try {
            Stop-Process -Id $p.ProcessId -Force
            $stoppedCount++
        } catch {
            Write-Warning "Failed to stop PID $($p.ProcessId): $($_.Exception.Message)"
        }
    }
}

# --- Remove startup shortcut (optional) --------------------------------------

if ($RemoveStartup) {
    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupFolder "ocr_watch.lnk"
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Host "Removed startup shortcut: $shortcutPath"
    } else {
        Write-Host "Startup shortcut not present: $shortcutPath"
    }
}

if ($stoppedCount -eq 0) {
    Write-Host "No ocr_watch processes were running."
} else {
    Write-Host "Stopped $stoppedCount process(es)."
}

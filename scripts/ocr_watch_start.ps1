<#
.SYNOPSIS
  cmd_721 Pattern B: start the OCR watchdog daemon on Windows.

.DESCRIPTION
  Launches scripts\ocr_watch.py in a hidden, detached process so the OCR
  pipeline runs in the background until the user logs out or stops it
  via ocr_watch_stop.ps1. Optionally registers the launcher to run at
  user logon via the Startup folder (Drive Desktop also needs to start
  automatically — see docs\ocr_pattern_b_runbook.md).

.PARAMETER WatchDir
  Folder to watch. Default: "$env:USERPROFILE\Google Drive\My Drive\OCR\input"

.PARAMETER PythonExe
  Python executable. Default: the venv at .\venv\Scripts\python.exe if it
  exists, otherwise "python" on PATH.

.PARAMETER EnableTcy
  Forward --enable-tcy to ocr_pdf.py (for vertical text PDFs).

.PARAMETER LogDir
  Folder for daemon stdout/stderr. Default: $env:LOCALAPPDATA\ocr_watch

.PARAMETER InstallStartup
  Create a startup shortcut so this script runs at logon.

.PARAMETER Foreground
  Run in the current console window (no detach). Useful for debugging.

.EXAMPLE
  PS> .\scripts\ocr_watch_start.ps1

.EXAMPLE
  PS> .\scripts\ocr_watch_start.ps1 -EnableTcy -InstallStartup

.NOTES
  - This script does not retry on errors; see scripts\ocr_watch.py docs.
  - Requires Python and the `watchdog` package (installed by setup_pattern_b.ps1).
#>

[CmdletBinding()]
param(
    [string] $WatchDir = "$env:USERPROFILE\Google Drive\My Drive\OCR\input",
    [string] $PythonExe = "",
    [switch] $EnableTcy,
    [string] $LogDir = (Join-Path $env:LOCALAPPDATA "ocr_watch"),
    [switch] $InstallStartup,
    [switch] $Foreground
)

$ErrorActionPreference = "Stop"

# --- Resolve paths -----------------------------------------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
$OcrWatch = Join-Path $ScriptRoot "ocr_watch.py"
$OcrPdf   = Join-Path $ScriptRoot "ocr_pdf.py"

if (-not (Test-Path -LiteralPath $OcrWatch)) {
    throw "ocr_watch.py not found at: $OcrWatch"
}

if (-not (Test-Path -LiteralPath $WatchDir)) {
    Write-Warning "Watch folder does not exist; creating: $WatchDir"
    New-Item -ItemType Directory -Force -Path $WatchDir | Out-Null
}

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

# Pick Python: explicit > venv > PATH
if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $venvPy = Join-Path $RepoRoot "venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $venvPy) {
        $PythonExe = $venvPy
    } else {
        $PythonExe = "python"
    }
}

# Sanity check: ocr_pdf.py warning (α may not be done yet)
if (-not (Test-Path -LiteralPath $OcrPdf)) {
    Write-Warning "ocr_pdf.py not found at: $OcrPdf (α subtask_721a 未完?)"
    Write-Warning "ocr_watch will log a 'ocr_pdf script missing' error per new PDF until α completes."
}

# --- Build argument list -----------------------------------------------------

$pyArgs = @(
    $OcrWatch,
    "--watch-dir", $WatchDir,
    "--ocr-script", $OcrPdf,
    "--python", $PythonExe
)
if ($EnableTcy) { $pyArgs += "--enable-tcy" }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stdoutLog = Join-Path $LogDir "ocr_watch_${timestamp}.out.log"
$stderrLog = Join-Path $LogDir "ocr_watch_${timestamp}.err.log"
$pidFile   = Join-Path $LogDir "ocr_watch.pid"

Write-Host "Python   : $PythonExe"
Write-Host "Script   : $OcrWatch"
Write-Host "WatchDir : $WatchDir"
Write-Host "LogDir   : $LogDir"
Write-Host "EnableTcy: $EnableTcy"

# --- Install startup shortcut (optional) ------------------------------------

if ($InstallStartup) {
    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupFolder "ocr_watch.lnk"
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $argsList = @(
        "-NoProfile",
        "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$($MyInvocation.MyCommand.Path)`""
    )
    if ($EnableTcy) { $argsList += "-EnableTcy" }
    $shortcut.Arguments = ($argsList -join " ")
    $shortcut.WorkingDirectory = $RepoRoot
    $shortcut.WindowStyle = 7  # Minimized
    $shortcut.Description = "ocr_watch.py — Pattern B daemon"
    $shortcut.Save()
    Write-Host "Installed startup shortcut: $shortcutPath"
}

# --- Launch ------------------------------------------------------------------

if ($Foreground) {
    Write-Host "Running in foreground (Ctrl+C to stop)..."
    & $PythonExe @pyArgs
    exit $LASTEXITCODE
}

$proc = Start-Process `
    -FilePath $PythonExe `
    -ArgumentList $pyArgs `
    -WorkingDirectory $RepoRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

$proc.Id | Out-File -FilePath $pidFile -Encoding ascii -Force
Write-Host "Started ocr_watch (PID $($proc.Id))"
Write-Host "PID file : $pidFile"
Write-Host "stdout   : $stdoutLog"
Write-Host "stderr   : $stderrLog"
Write-Host "Stop with: scripts\ocr_watch_stop.ps1"

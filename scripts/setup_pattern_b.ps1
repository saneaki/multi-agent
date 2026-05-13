<#
.SYNOPSIS
  cmd_721 Pattern B setup for Windows 10/11 — installs NDL OCR Lite + PyMuPDF.

.DESCRIPTION
  Provisions everything needed to run scripts/ocr_pdf.py and scripts/ocr_watch.py
  on the Lord's Windows PC.

  Steps performed:
    1. Python 3.10..3.13 detection (refuses 3.14+ and < 3.10).
    2. Virtual environment creation under .\.venv_pattern_b (path is overridable).
    3. pip install -r requirements.txt (PyMuPDF / Pillow / watchdog / pyyaml).
    4. git clone of NDL OCR Lite v1.2.1 into .\external\ndlocr-lite
       (skipped if already present).
    5. pip install -r ndlocr-lite\requirements.txt (so its CLI is runnable).
    6. Verification: --help + --dry-run on a tiny throw-away PDF.

  Designed to be idempotent: re-running it is safe and only re-installs what
  is missing. Output paths are kept ASCII-only (NDL OCR Lite GUI fails on
  全角文字 in its install path; the CLI tolerates Unicode paths but we stay
  conservative for parity).

.PARAMETER VenvPath
  Where to create the venv. Default: ".\.venv_pattern_b" (relative to repo root).

.PARAMETER NdlHome
  Where to clone NDL OCR Lite. Default: ".\external\ndlocr-lite".

.PARAMETER SkipNdlClone
  Skip cloning/updating NDL OCR Lite. Use when you've installed it manually
  or via `uv tool install`.

.PARAMETER Force
  Recreate the venv from scratch.

.EXAMPLE
  PS> .\scripts\setup_pattern_b.ps1

.EXAMPLE
  PS> .\scripts\setup_pattern_b.ps1 -VenvPath D:\ocr\.venv -NdlHome D:\ocr\ndlocr-lite

.NOTES
  cmd_721 Pattern B is fully offline. This script is the ONLY step that needs
  network access (pip + git clone). After setup, all runs are local.
#>
[CmdletBinding()]
param(
    [string]$VenvPath = ".\.venv_pattern_b",
    [string]$NdlHome = ".\external\ndlocr-lite",
    [switch]$SkipNdlClone,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$NdlVersionTag = "1.2.1"  # NDL OCR Lite release pin (cmd_720a)
$NdlRepoUrl = "https://github.com/ndl-lab/ndlocr-lite"

function Write-Step([string]$msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "    OK: $msg" -ForegroundColor Green
}

function Write-Warn2([string]$msg) {
    Write-Host "    WARN: $msg" -ForegroundColor Yellow
}

function Resolve-AbsPath([string]$p) {
    if ([System.IO.Path]::IsPathRooted($p)) { return $p }
    return (Join-Path $RepoRoot $p)
}

function Find-PythonInRange {
    # Returns the highest-priority Python interpreter in [3.10, 3.13]
    # using `py -0p` (Python launcher) first, then PATH fallback.
    $candidates = @()

    # Windows Python launcher: lists installed versions
    try {
        $pyList = & py -0p 2>$null
        foreach ($line in $pyList) {
            # Format: " -V:3.12 *        C:\Python312\python.exe"
            if ($line -match "(\d+\.\d+)\s+\*?\s+(.+)$") {
                $ver = $matches[1]
                $exe = $matches[2].Trim()
                $candidates += [pscustomobject]@{ Version = $ver; Exe = $exe }
            }
        }
    } catch {
        # py launcher absent; ignore
    }

    # Direct PATH lookup
    foreach ($name in @("python", "python3", "python3.13", "python3.12", "python3.11", "python3.10")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $verOut = & $cmd.Source -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
            if ($verOut) {
                $candidates += [pscustomobject]@{ Version = $verOut.Trim(); Exe = $cmd.Source }
            }
        }
    }

    foreach ($c in $candidates) {
        $vparts = $c.Version.Split(".")
        if ($vparts.Count -ge 2) {
            $major = [int]$vparts[0]
            $minor = [int]$vparts[1]
            if ($major -eq 3 -and $minor -ge 10 -and $minor -le 13) {
                return $c
            }
        }
    }
    return $null
}

# --- Step 1: Python detection -------------------------------------------------
Write-Step "Detecting Python 3.10..3.13"
$py = Find-PythonInRange
if (-not $py) {
    throw "No Python in [3.10, 3.13] found. Install from https://www.python.org/downloads/ (3.12 recommended)."
}
Write-Ok ("Python {0} at {1}" -f $py.Version, $py.Exe)

# --- Step 2: Virtualenv -------------------------------------------------------
$VenvAbs = Resolve-AbsPath $VenvPath
Write-Step "Provisioning venv at $VenvAbs"
if ($Force -and (Test-Path $VenvAbs)) {
    Write-Warn2 "Removing existing venv (--Force)"
    Remove-Item -Recurse -Force $VenvAbs
}
if (-not (Test-Path $VenvAbs)) {
    & $py.Exe -m venv $VenvAbs
    Write-Ok "venv created"
} else {
    Write-Ok "venv already exists; reusing"
}

$VenvPython = Join-Path $VenvAbs "Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    throw "venv python not found at $VenvPython"
}

# --- Step 3: pip install requirements.txt -------------------------------------
$ReqFile = Join-Path $RepoRoot "requirements.txt"
if (-not (Test-Path $ReqFile)) {
    throw "requirements.txt missing at $ReqFile"
}
Write-Step "Installing repo requirements ($ReqFile)"
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r $ReqFile
Write-Ok "shogun requirements installed"

# --- Step 4: Clone NDL OCR Lite -----------------------------------------------
$NdlAbs = Resolve-AbsPath $NdlHome
if ($SkipNdlClone) {
    Write-Step "Skipping NDL OCR Lite clone (--SkipNdlClone)"
} else {
    Write-Step "Cloning/refreshing NDL OCR Lite v$NdlVersionTag at $NdlAbs"
    $ndlGit = Join-Path $NdlAbs ".git"
    if (-not (Test-Path $ndlGit)) {
        $parent = Split-Path -Parent $NdlAbs
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        & git clone --branch $NdlVersionTag --depth 1 $NdlRepoUrl $NdlAbs
        if ($LASTEXITCODE -ne 0) {
            Write-Warn2 "Tag '$NdlVersionTag' clone failed; falling back to default branch."
            & git clone --depth 1 $NdlRepoUrl $NdlAbs
            if ($LASTEXITCODE -ne 0) {
                throw "git clone of NDL OCR Lite failed."
            }
        }
        Write-Ok "NDL OCR Lite cloned"
    } else {
        Push-Location $NdlAbs
        try {
            & git fetch --depth 1 origin $NdlVersionTag 2>$null
            & git checkout $NdlVersionTag 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warn2 "Could not check out tag $NdlVersionTag; staying on current HEAD."
            }
        } finally {
            Pop-Location
        }
        Write-Ok "NDL OCR Lite already cloned"
    }

    $NdlReq = Join-Path $NdlAbs "requirements.txt"
    if (-not (Test-Path $NdlReq)) {
        throw "NDL OCR Lite requirements.txt not found at $NdlReq"
    }
    Write-Step "Installing NDL OCR Lite requirements"
    & $VenvPython -m pip install -r $NdlReq
    Write-Ok "NDL OCR Lite requirements installed"

    # Sanity-check the model files exist (they ship in the repo, ~157MB total).
    $ModelDir = Join-Path $NdlAbs "src\model"
    $missingModels = @()
    foreach ($m in @(
        "deim-s-1024x1024.onnx",
        "parseq-ndl-24x256-30-tiny-189epoch-tegaki3-r8data-202604.onnx",
        "parseq-ndl-24x384-50-tiny-300epoch-tegaki3-r8data-202604.onnx",
        "parseq-ndl-24x768-100-tiny-153epoch-tegaki3-r8data-202604.onnx"
    )) {
        $full = Join-Path $ModelDir $m
        if (-not (Test-Path $full)) { $missingModels += $m }
    }
    if ($missingModels.Count -gt 0) {
        Write-Warn2 ("Missing ONNX model file(s): {0}" -f ($missingModels -join ", "))
        Write-Warn2 "If the clone used --depth 1, retry without --depth or re-clone fully."
    } else {
        Write-Ok "NDL OCR Lite ONNX models present"
    }
}

# --- Step 5: Verification -----------------------------------------------------
$OcrScript = Join-Path $RepoRoot "scripts\ocr_pdf.py"
if (-not (Test-Path $OcrScript)) {
    throw "scripts\ocr_pdf.py not found at $OcrScript"
}

Write-Step "Verifying ocr_pdf.py --help"
& $VenvPython $OcrScript --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "ocr_pdf.py --help failed (exit $LASTEXITCODE)"
}
Write-Ok "ocr_pdf.py --help OK"

Write-Step "Creating throwaway PDF for --dry-run"
$TmpPdf = Join-Path $env:TEMP "cmd_721_setup_check.pdf"
& $VenvPython -c @"
import fitz
doc = fitz.open()
page = doc.new_page()
page.insert_text((72, 72), 'cmd_721 Pattern B setup smoke test', fontsize=14)
doc.save(r'$TmpPdf')
"@
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create throwaway PDF via PyMuPDF."
}
Write-Ok "throwaway PDF at $TmpPdf"

Write-Step "Running ocr_pdf.py --dry-run"
$dryArgs = @($OcrScript, $TmpPdf, "--dry-run")
if (-not $SkipNdlClone) {
    $dryArgs += @("--ndl-home", $NdlAbs)
}
& $VenvPython @dryArgs
if ($LASTEXITCODE -ne 0) {
    throw "ocr_pdf.py --dry-run failed (exit $LASTEXITCODE)"
}
Write-Ok "ocr_pdf.py --dry-run OK"

Remove-Item -Force $TmpPdf -ErrorAction SilentlyContinue

# --- Summary ------------------------------------------------------------------
Write-Host ""
Write-Host "=== cmd_721 Pattern B setup complete ===" -ForegroundColor Green
Write-Host "  venv         : $VenvAbs"
Write-Host "  python       : $VenvPython"
if (-not $SkipNdlClone) {
    Write-Host "  ndl-home     : $NdlAbs"
}
Write-Host ""
Write-Host "Run OCR with:"
$exampleArgs = if ($SkipNdlClone) {
    "scripts\ocr_pdf.py <input.pdf>"
} else {
    "scripts\ocr_pdf.py <input.pdf> --ndl-home `"$NdlAbs`""
}
Write-Host "  & `"$VenvPython`" $exampleArgs"
Write-Host ""
Write-Host "β (watchdog daemon) will reuse the same venv and --ndl-home."

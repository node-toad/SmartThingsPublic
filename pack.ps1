#Requires -Version 5.1
<#
.SYNOPSIS
    Packages the AnythingLLM Launcher into a distributable ZIP and a
    single-file self-extracting installer.
.DESCRIPTION
    Produces two outputs in -OutputDir:

      AnythingLLM_Launcher_v<Version>.zip
          Traditional ZIP — extract anywhere and run run.bat.

      AnythingLLM_Launcher_v<Version>_Setup.ps1
          Self-extracting single-file installer. All launcher files are
          embedded as base64. SHA-256 hashes are embedded for integrity
          verification on extraction. No internet required.

    Run once to build, then share either output with end users.
.EXAMPLE
    .\pack.ps1
    .\pack.ps1 -OutputDir C:\releases
    .\pack.ps1 -OutputDir C:\releases -Version 2.0
#>
[CmdletBinding()]
param(
    [string]$OutputDir = $PSScriptRoot,
    [string]$Version   = "1.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PackageName = "AnythingLLM_Launcher_v$Version"
$Root        = $PSScriptRoot

# ---------------------------------------------------------------------------
# Files to bundle
# ---------------------------------------------------------------------------
$BUNDLE = @(
    "run.bat",
    "anythingllm_v1.py",
    "launch_anythingllm.bat",
    "launch_anythingllm.ps1",
    "setup_anythingllm.bat",
    "README.md"
)

# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------
function Write-Header {
    Write-Host ""
    Write-Host "  #############################################################" -ForegroundColor Cyan
    Write-Host "  #   AnythingLLM Launcher  v$Version  --  Pack Tool           " -ForegroundColor Cyan
    Write-Host "  #############################################################" -ForegroundColor Cyan
    Write-Host ""
}
function Write-Section([string]$t) { Write-Host "  --- $t " -ForegroundColor Yellow }
function Write-Step([string]$t)    { Write-Host "  [>] $t"  -ForegroundColor Cyan   }
function Write-Ok([string]$t)      { Write-Host "  [+] $t"  -ForegroundColor Green  }
function Write-Fail([string]$t)    { Write-Host "  [!] $t"  -ForegroundColor Red    }

Write-Header

# ---------------------------------------------------------------------------
# 1 — Verify source files
# ---------------------------------------------------------------------------
Write-Section "Verifying source files"
Write-Host ""

$missing = $false
foreach ($f in $BUNDLE) {
    if (Test-Path (Join-Path $Root $f)) {
        $size = (Get-Item (Join-Path $Root $f)).Length
        Write-Host ("    {0,-32} {1,8} bytes" -f $f, $size) -ForegroundColor DarkGray
    } else {
        Write-Fail "MISSING  $f"
        $missing = $true
    }
}
if ($missing) {
    Write-Host ""
    Write-Fail "One or more source files are missing. Aborting."
    exit 1
}

# ---------------------------------------------------------------------------
# 2 — Read, hash, and encode every file
# ---------------------------------------------------------------------------
Write-Host ""
Write-Section "Reading and encoding files"
Write-Host ""

$sha256   = [System.Security.Cryptography.SHA256]::Create()
$encoded  = [ordered]@{}   # filename -> base64
$hashes   = [ordered]@{}   # filename -> hex sha256

foreach ($f in $BUNDLE) {
    $bytes        = [System.IO.File]::ReadAllBytes((Join-Path $Root $f))
    $encoded[$f]  = [Convert]::ToBase64String($bytes)
    $hashBytes    = $sha256.ComputeHash($bytes)
    $hashes[$f]   = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
    Write-Host ("    {0,-32} SHA256: {1}" -f $f, $hashes[$f].Substring(0,16) + "...") -ForegroundColor DarkGray
}
$sha256.Dispose()

# ---------------------------------------------------------------------------
# 3 — Build ZIP archive
# ---------------------------------------------------------------------------
Write-Host ""
Write-Section "Creating ZIP archive"
Write-Host ""

Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipPath = Join-Path $OutputDir "$PackageName.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')
foreach ($f in $BUNDLE) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip,
        (Join-Path $Root $f),
        $f,
        [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
}
$zip.Dispose()

$zipSize = [math]::Round((Get-Item $ZipPath).Length / 1KB, 1)
Write-Ok "ZIP created  ($zipSize KB)  →  $ZipPath"

# ---------------------------------------------------------------------------
# 4 — Build self-extracting installer
# ---------------------------------------------------------------------------
Write-Host ""
Write-Section "Generating self-extracting installer"
Write-Host ""

# Serialize embedded data as PowerShell ordered-hashtable literals
function ConvertTo-PSLiteral([System.Collections.Specialized.OrderedDictionary]$ht) {
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("[ordered]@{")
    foreach ($kv in $ht.GetEnumerator()) {
        $null = $sb.AppendLine("    '$($kv.Key)' = '$($kv.Value)'")
    }
    $null = $sb.Append("}")
    return $sb.ToString()
}

$filesLiteral  = ConvertTo-PSLiteral $encoded
$hashesLiteral = ConvertTo-PSLiteral $hashes

# Timestamp for the generated file header
$buildStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ---- Installer template (backtick-escaped $ for runtime vars) ----
$installer = @"
#Requires -Version 5.1
<#
    AnythingLLM Launcher  v$Version  --  Self-Extracting Installer
    Generated by pack.ps1 on $buildStamp

    All launcher files are embedded as base64 with SHA-256 integrity
    checks. No internet connection required.

    USAGE
        Double-click, or from PowerShell:
            .\${PackageName}_Setup.ps1
            .\${PackageName}_Setup.ps1 -InstallDir "C:\Tools\AnythingLLM"
            .\${PackageName}_Setup.ps1 -InstallDir "C:\Tools\AnythingLLM" -Silent

    PARAMETERS
        -InstallDir   Target folder (prompted interactively if omitted)
        -NoShortcut   Skip desktop and Start-Menu shortcut creation
        -Silent       Non-interactive; uses defaults, skips all prompts
#>
param(
    [string]`$InstallDir = "",
    [switch]`$NoShortcut,
    [switch]`$Silent
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

# ==========================================================================
# EMBEDDED DATA  (generated by pack.ps1 -- do not edit manually)
# ==========================================================================
`$_FILES = $filesLiteral

`$_HASHES = $hashesLiteral

# ==========================================================================
# INTERNALS
# ==========================================================================
`$_VERSION  = "$Version"
`$_APPNAME  = "AnythingLLM Launcher"
`$_PKGNAME  = "$PackageName"

function _Write-Banner {
    Write-Host ""
    Write-Host "  ##############################################################" -ForegroundColor Cyan
    Write-Host "  ##  `$_APPNAME  v`$_VERSION  --  Installer               " -ForegroundColor Cyan
    Write-Host "  ##############################################################" -ForegroundColor Cyan
    Write-Host ""
}

function _Write-Section([string]`$t) { Write-Host "" ; Write-Host "  --- `$t " -ForegroundColor Yellow ; Write-Host "" }
function _Write-Ok([string]`$t)      { Write-Host "  [+] `$t" -ForegroundColor Green  }
function _Write-Warn([string]`$t)    { Write-Host "  [~] `$t" -ForegroundColor Yellow }
function _Write-Fail([string]`$t)    { Write-Host "  [!] `$t" -ForegroundColor Red    }

function _Check-Tool([string]`$Name, [string]`$Cmd, [string]`$Url, [bool]`$Required = `$false) {
    `$found = Get-Command `$Cmd -ErrorAction SilentlyContinue
    if (-not `$found) {
        if (`$Required) {
            _Write-Fail "`$Name  NOT FOUND  (required)  --  `$Url"
        } else {
            _Write-Warn "`$Name  not found  (optional) --  `$Url"
        }
        return `$false
    }
    `$ver = (& `$Cmd --version 2>&1) | Select-Object -First 1
    _Write-Ok "`$Name  `$ver"
    return `$true
}

function _Verify-Hash([string]`$File, [byte[]]`$Bytes) {
    `$sha  = [System.Security.Cryptography.SHA256]::Create()
    `$got  = (`$sha.ComputeHash(`$Bytes) | ForEach-Object { `$_.ToString("x2") }) -join ""
    `$sha.Dispose()
    `$want = `$_HASHES[`$File]
    if (`$got -ne `$want) {
        throw "Integrity check failed for '`$File'.`nExpected: `$want`nGot:      `$got"
    }
}

function _Find-Python {
    foreach (`$candidate in @("pythonw", "python3", "python")) {
        `$cmd = Get-Command `$candidate -ErrorAction SilentlyContinue
        if (`$cmd) { return `$cmd.Source }
    }
    return "python"
}

function _Create-Shortcut([string]`$LnkPath, [string]`$Target, [string]`$Args, [string]`$WorkDir, [string]`$Desc) {
    `$wsh        = New-Object -ComObject WScript.Shell
    `$lnk        = `$wsh.CreateShortcut(`$LnkPath)
    `$lnk.TargetPath       = `$Target
    `$lnk.Arguments        = `$Args
    `$lnk.WorkingDirectory = `$WorkDir
    `$lnk.Description      = `$Desc
    `$lnk.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject(`$wsh) | Out-Null
}

# ==========================================================================
# MAIN
# ==========================================================================
_Write-Banner

# --------------------------------------------------------------------------
# Prerequisites
# --------------------------------------------------------------------------
_Write-Section "Prerequisites"

`$hasPython = _Check-Tool "Python 3" "python"  "https://python.org/"      `$false
`$hasNode   = _Check-Tool "Node.js"  "node"    "https://nodejs.org/"      `$false
`$hasNpm    = _Check-Tool "npm"      "npm"     "https://nodejs.org/"      `$false
               _Check-Tool "yarn"    "yarn"    "https://yarnpkg.com/"     `$false | Out-Null

Write-Host ""
if (-not `$hasPython) {
    _Write-Warn "Python 3 not found. The GUI (run.bat / anythingllm_v1.py) needs it."
    _Write-Warn "Install from https://python.org/ then re-launch run.bat."
}
if (-not `$hasNode -or -not `$hasNpm) {
    _Write-Warn "Node.js / npm not found. AnythingLLM itself needs them."
    _Write-Warn "Install from https://nodejs.org/ then run setup_anythingllm.bat."
}

if ((-not `$hasPython -or -not `$hasNode) -and -not `$Silent) {
    `$cont = Read-Host "  [?] Continue installation anyway? (Y/n)"
    if (`$cont -imatch '^n') { exit 0 }
}

# --------------------------------------------------------------------------
# Choose install directory
# --------------------------------------------------------------------------
_Write-Section "Install Location"

if (`$InstallDir -eq "") {
    `$defaultDir = Join-Path `$env:USERPROFILE "`$_APPNAME"
    if (`$Silent) {
        `$InstallDir = `$defaultDir
    } else {
        `$choice = Read-Host "  [?] Install directory  (blank = `$defaultDir)"
        `$InstallDir = if (`$choice.Trim() -eq "") { `$defaultDir } else { `$choice.Trim() }
    }
}

if (Test-Path `$InstallDir) {
    if (-not `$Silent) {
        `$ow = Read-Host "  [?] '`$InstallDir' already exists. Overwrite? (Y/n)"
        if (`$ow -imatch '^n') { Write-Host "  Cancelled." ; exit 0 }
    }
    _Write-Warn "Overwriting existing files in `$InstallDir"
} else {
    New-Item -ItemType Directory -Path `$InstallDir -Force | Out-Null
    _Write-Ok "Created  `$InstallDir"
}

# --------------------------------------------------------------------------
# Extract and verify files
# --------------------------------------------------------------------------
_Write-Section "Extracting Files"

foreach (`$entry in `$_FILES.GetEnumerator()) {
    `$name  = `$entry.Key
    `$bytes = [Convert]::FromBase64String(`$entry.Value)
    _Verify-Hash `$name `$bytes
    `$dest = Join-Path `$InstallDir `$name
    [System.IO.File]::WriteAllBytes(`$dest, `$bytes)
    _Write-Ok `$name
}

# --------------------------------------------------------------------------
# Write uninstaller
# --------------------------------------------------------------------------
`$uninstPath = Join-Path `$InstallDir "uninstall.ps1"
`$uninstContent = @'
#Requires -Version 5.1
param([switch]`$Silent)
`$dir = Split-Path -Parent `$MyInvocation.MyCommand.Path
Write-Host ""
Write-Host "  AnythingLLM Launcher -- Uninstaller" -ForegroundColor Yellow
Write-Host ""
if (-not `$Silent) {
    `$c = Read-Host "  Remove '`$dir' and all shortcuts? (y/N)"
    if (`$c -notmatch '^y') { Write-Host "  Cancelled."; exit 0 }
}
`$wsh     = New-Object -ComObject WScript.Shell
`$desktop = `$wsh.SpecialFolders("Desktop")
`$startM  = `$wsh.SpecialFolders("Programs")
`$lnk1 = Join-Path `$desktop  "AnythingLLM Launcher.lnk"
`$lnk2 = Join-Path `$startM   "AnythingLLM Launcher\AnythingLLM Launcher.lnk"
if (Test-Path `$lnk1) { Remove-Item `$lnk1 -Force; Write-Host "  [+] Removed desktop shortcut" -ForegroundColor Green }
if (Test-Path `$lnk2) { Remove-Item (Split-Path `$lnk2) -Recurse -Force; Write-Host "  [+] Removed Start Menu entry" -ForegroundColor Green }
[System.Runtime.InteropServices.Marshal]::ReleaseComObject(`$wsh) | Out-Null
Remove-Item `$dir -Recurse -Force
Write-Host "  [+] Removed `$dir" -ForegroundColor Green
Write-Host ""
Write-Host "  Uninstall complete." -ForegroundColor Green
'@
[System.IO.File]::WriteAllText(`$uninstPath, `$uninstContent, [System.Text.Encoding]::UTF8)
_Write-Ok "uninstall.ps1  (run to remove all files and shortcuts)"

# --------------------------------------------------------------------------
# Shortcuts
# --------------------------------------------------------------------------
if (-not `$NoShortcut) {
    `$createSC = `$true
    if (-not `$Silent) {
        `$sc = Read-Host "  [?] Create shortcuts (Desktop + Start Menu)? (Y/n)"
        `$createSC = `$sc -notmatch '^n'
    }

    if (`$createSC) {
        _Write-Section "Creating Shortcuts"

        `$pyExe   = _Find-Python
        `$pyArg   = "`"`$(Join-Path `$InstallDir 'anythingllm_v1.py')`""
        `$desc    = "`$_APPNAME v`$_VERSION"
        `$wsh     = New-Object -ComObject WScript.Shell

        # Desktop shortcut
        `$desktopLnk = Join-Path (`$wsh.SpecialFolders("Desktop")) "`$_APPNAME.lnk"
        _Create-Shortcut `$desktopLnk `$pyExe `$pyArg `$InstallDir `$desc
        _Write-Ok "Desktop  ->  `$desktopLnk"

        # Start Menu shortcut
        `$startDir = Join-Path (`$wsh.SpecialFolders("Programs")) `$_APPNAME
        if (-not (Test-Path `$startDir)) { New-Item -ItemType Directory `$startDir -Force | Out-Null }
        `$startLnk = Join-Path `$startDir "`$_APPNAME.lnk"
        _Create-Shortcut `$startLnk `$pyExe `$pyArg `$InstallDir `$desc
        _Write-Ok "Start Menu  ->  `$startLnk"

        [System.Runtime.InteropServices.Marshal]::ReleaseComObject(`$wsh) | Out-Null
    }
}

# --------------------------------------------------------------------------
# Done
# --------------------------------------------------------------------------
Write-Host ""
Write-Host "  ##############################################################" -ForegroundColor Green
Write-Host "    Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "    Location : `$InstallDir" -ForegroundColor Green
Write-Host ""
Write-Host "    NEXT STEPS:" -ForegroundColor Yellow
Write-Host "      1. Run setup_anythingllm.bat  (first time only)" -ForegroundColor White
Write-Host "         Installs Node.js deps and clones AnythingLLM." -ForegroundColor DarkGray
Write-Host "      2. Run run.bat  (or use the desktop shortcut)" -ForegroundColor White
Write-Host "         Opens the launcher GUI." -ForegroundColor DarkGray
Write-Host "      3. Enter API key + model, click Launch." -ForegroundColor White
Write-Host ""
Write-Host "    To uninstall: run uninstall.ps1 inside the install folder." -ForegroundColor DarkGray
Write-Host "  ##############################################################" -ForegroundColor Green
Write-Host ""

if (-not `$Silent) {
    `$openDir = Read-Host "  [?] Open install folder in Explorer? (Y/n)"
    if (`$openDir -notmatch '^n') { Start-Process explorer.exe `$InstallDir }
}
"@

$SetupPath = Join-Path $OutputDir "${PackageName}_Setup.ps1"
[System.IO.File]::WriteAllText($SetupPath, $installer, [System.Text.Encoding]::UTF8)

$setupSize = [math]::Round((Get-Item $SetupPath).Length / 1KB, 1)
Write-Ok "Installer created  ($setupSize KB)  →  $SetupPath"

# ---------------------------------------------------------------------------
# 5 — Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ##############################################################" -ForegroundColor Green
Write-Host "    Pack complete  --  $PackageName" -ForegroundColor Green
Write-Host ""
Write-Host ("    ZIP        {0,-8} KB   {1}" -f $zipSize,   $ZipPath)   -ForegroundColor Green
Write-Host ("    Installer  {0,-8} KB   {1}" -f $setupSize, $SetupPath) -ForegroundColor Green
Write-Host ""
Write-Host "    The installer is fully self-contained — one file," -ForegroundColor DarkGray
Write-Host "    no internet needed, works on any Windows 10/11 PC." -ForegroundColor DarkGray
Write-Host "  ##############################################################" -ForegroundColor Green
Write-Host ""

@echo off
setlocal EnableDelayedExpansion
title AnythingLLM Launcher — Pack Tool

:: ================================================================
::  pack.bat  —  Final Pack-and-Go Builder
::
::  Calls pack.ps1 to produce two distributable files:
::
::    AnythingLLM_Launcher_v1.1.zip
::        Traditional ZIP archive.  Extract anywhere, run run.bat.
::
::    AnythingLLM_Launcher_v1.1_Setup.ps1
::        Single-file self-extracting installer.  All launcher files
::        are embedded.  Share this one file with end users — they
::        just right-click and "Run with PowerShell".
::
::  USAGE
::    pack.bat                  outputs to same folder as this script
::    pack.bat "C:\releases"    outputs to a custom folder
:: ================================================================

echo.
echo  ##############################################################
echo  ##  AnythingLLM Launcher  --  Pack-and-Go Builder
echo  ##############################################################
echo.

:: ---- Require PowerShell ----
where powershell >nul 2>&1
if errorlevel 1 (
    echo  [!] PowerShell is required but was not found.
    echo      Windows 10 and 11 include it by default.
    echo.
    pause
    exit /b 1
)

:: ---- Require pack.ps1 alongside this file ----
if not exist "%~dp0pack.ps1" (
    echo  [!] pack.ps1 not found next to pack.bat.
    echo      Both files must be in the same directory.
    echo.
    pause
    exit /b 1
)

:: ---- Resolve output directory ----
set "OUT_DIR=%~dp0"
if not "%~1"=="" (
    set "OUT_DIR=%~1"
    echo  [>] Output directory : %OUT_DIR%
) else (
    echo  [>] Output directory : %~dp0  (same folder as this script)
)
echo.

:: ---- Run pack.ps1 ----
powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "%~dp0pack.ps1" ^
    -OutputDir "%OUT_DIR%"

if errorlevel 1 (
    echo.
    echo  [!] Pack failed. Review the messages above.
    pause
    exit /b 1
)

echo.
echo  Press any key to close ...
pause >nul

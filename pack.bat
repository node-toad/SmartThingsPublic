@echo off
setlocal EnableDelayedExpansion
title AnythingLLM Launcher — Pack Tool

:: ============================================================
::  pack.bat
::  Wrapper that calls pack.ps1 to produce:
::    • AnythingLLM_Launcher_v1.1.zip
::    • AnythingLLM_Launcher_v1.1_Setup.ps1  (self-extracting)
:: ============================================================

echo.
echo  AnythingLLM Launcher Pack Tool
echo  ================================
echo.

:: Verify PowerShell is available
where powershell >nul 2>&1
if errorlevel 1 (
    echo  [!] PowerShell is required to run this script.
    echo      It ships with Windows 10/11 and is free at:
    echo      https://github.com/PowerShell/PowerShell
    pause
    exit /b 1
)

:: Optional: let user pass a custom output directory
set "OUT_DIR=%~dp0"
if not "%~1"=="" set "OUT_DIR=%~1"

echo  Packaging files ...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack.ps1" -OutputDir "%OUT_DIR%"

if errorlevel 1 (
    echo.
    echo  [!] Pack failed. See messages above.
    pause
    exit /b 1
)

pause

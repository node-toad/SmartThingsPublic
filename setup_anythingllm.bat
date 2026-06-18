@echo off
setlocal EnableDelayedExpansion
title AnythingLLM Setup

:: ============================================================
::  AnythingLLM Setup Script
::  Checks prerequisites and optionally clones AnythingLLM
:: ============================================================

call :set_colors
echo.
echo  !CYAN!======================================================!RESET!
echo  !CYAN!  AnythingLLM Setup ^& Prerequisites Check!RESET!
echo  !CYAN!======================================================!RESET!
echo.

set "PASS=0"
set "FAIL=0"

:: ---- Node.js ----
call :check_tool "node" "--version" "Node.js"
call :check_tool "npm"  "--version" "npm"

:: ---- Yarn (optional) ----
where yarn >nul 2>&1 && (
    echo  !GREEN![+] yarn     found!RESET!
) || (
    echo  !YELLOW![-] yarn     not found (optional, npm will be used instead)!RESET!
)

:: ---- Git ----
call :check_tool "git" "--version" "Git"

echo.
if !FAIL! gtr 0 (
    echo  !RED![!] Some prerequisites are missing.!RESET!
    echo  !YELLOW!  Install Node.js: https://nodejs.org/!RESET!
    echo  !YELLOW!  Install Git:     https://git-scm.com/!RESET!
    pause
    exit /b 1
)

echo  !GREEN![+] All required tools found.!RESET!
echo.

:: ---- Check if AnythingLLM already exists ----
if exist "%~dp0anythingllm\server\index.js" (
    echo  !GREEN![+] AnythingLLM already present at .\anythingllm!RESET!
    goto :install_deps
)

:: ---- Clone AnythingLLM ----
echo  !YELLOW![?] AnythingLLM not found. Clone it now?!RESET!
set /p "DO_CLONE= [?] Clone AnythingLLM into .\anythingllm? (Y/n): "
if /i "!DO_CLONE!"=="n" (
    echo  !YELLOW!Skipping clone. Place AnythingLLM in .\anythingllm manually.!RESET!
    goto :done
)

echo.
echo  !CYAN![>] Cloning AnythingLLM ...!RESET!
git clone --depth 1 https://github.com/Mintplex-Labs/anything-llm.git "%~dp0anythingllm"
if !errorlevel! neq 0 (
    echo  !RED![!] Clone failed. Check your internet connection.!RESET!
    pause
    exit /b 1
)
echo  !GREEN![+] Clone complete.!RESET!

:install_deps
echo.
echo  !CYAN![>] Installing server dependencies ...!RESET!
pushd "%~dp0anythingllm\server"

where yarn >nul 2>&1 && (
    yarn install
) || (
    npm install
)

if !errorlevel! neq 0 (
    echo  !RED![!] Dependency installation failed.!RESET!
    popd
    pause
    exit /b 1
)
popd

echo.
echo  !CYAN![>] Installing frontend dependencies ...!RESET!
if exist "%~dp0anythingllm\frontend" (
    pushd "%~dp0anythingllm\frontend"
    where yarn >nul 2>&1 && (yarn install) || (npm install)
    popd
)

:done
echo.
echo  !GREEN!======================================================!RESET!
echo  !GREEN!  Setup complete! Run launch_anythingllm.bat to start.!RESET!
echo  !GREEN!======================================================!RESET!
echo.
pause
exit /b 0

:: -------------------------------------------------------
:check_tool
    where %~1 >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%V in ('%~1 %~2 2^>^&1') do (
            echo  !GREEN![+] %~3    %%V!RESET!
            goto :check_done_%~1
        )
    )
    echo  !RED![x] %~3    NOT FOUND!RESET!
    set /a FAIL+=1
    :check_done_%~1
    goto :eof

:: -------------------------------------------------------
:set_colors
    for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
    set "RED=!ESC![91m"
    set "GREEN=!ESC![92m"
    set "YELLOW=!ESC![93m"
    set "CYAN=!ESC![96m"
    set "RESET=!ESC![0m"
    goto :eof

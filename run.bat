@echo off
:: ============================================================
::  AnythingLLM Launcher v1  —  run.bat
::  Starts the GUI app (Python) or falls back to the batch CLI
:: ============================================================
setlocal EnableDelayedExpansion
title AnythingLLM Launcher v1

where python >nul 2>&1 && (
    echo Starting AnythingLLM Launcher GUI ...
    python "%~dp0anythingllm_v1.py"
    goto :eof
)

where python3 >nul 2>&1 && (
    echo Starting AnythingLLM Launcher GUI ...
    python3 "%~dp0anythingllm_v1.py"
    goto :eof
)

echo Python not found — falling back to CLI launcher ...
call "%~dp0launch_anythingllm.bat"

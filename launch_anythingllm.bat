@echo off
setlocal EnableDelayedExpansion
title AnythingLLM Launcher

:: ============================================================
::  AnythingLLM Batch Launcher
::  Prompts for API key and model ID, then starts AnythingLLM
:: ============================================================

call :set_colors
call :banner
call :main
exit /b 0

:: -------------------------------------------------------
:main
    set "CONFIG_FILE=%~dp0anythingllm.config"
    set "LLM_PROVIDER="
    set "USER_API_KEY="
    set "USER_MODEL_ID="

    :: Load saved config if it exists
    if exist "%CONFIG_FILE%" (
        echo  [!CYAN!*!RESET!] Saved configuration detected.
        set /p "USE_SAVED= [?] Use saved settings? (Y/n): "
        if /i "!USE_SAVED!" neq "n" (
            call :load_config
            call :confirm_and_launch
            goto :eof
        )
        echo.
    )

    call :select_provider
    call :prompt_api_key
    call :prompt_model_id
    call :prompt_save_config
    call :launch
    goto :eof

:: -------------------------------------------------------
:banner
    echo.
    echo  !CYAN!==============================================================!RESET!
    echo  !CYAN!   _              _   _     _             _     _     __  __  !RESET!
    echo  !CYAN!  / \  _ __  _   | |_| |__ (_)_ __   __ _| |   | |   |  \/  | !RESET!
    echo  !CYAN! / _ \| '_ \| | | | __| '_ \| | '_ \ / _` | |   | |   | |\/| | !RESET!
    echo  !CYAN!/ ___ \ | | | |_| | |_| | | | | | | | (_| | |___| |___| |  | | !RESET!
    echo  !CYAN!/_/   \_\_| |_|\__, |\__|_| |_|_|_| |_|\__, |_____|_____|_|  |_| !RESET!
    echo  !CYAN!                |___/                   |___/                     !RESET!
    echo  !CYAN!==============================================================!RESET!
    echo   !YELLOW!Batch Launcher v1.0  --  API Key ^& Model Configurator!RESET!
    echo  !CYAN!==============================================================!RESET!
    echo.
    goto :eof

:: -------------------------------------------------------
:select_provider
    echo  !YELLOW!--- Select LLM Provider ------------------------------------------!RESET!
    echo.
    echo   [1] OpenAI          (gpt-4o, gpt-4-turbo, gpt-3.5-turbo ...)
    echo   [2] Anthropic        (claude-sonnet-4-6, claude-opus-4-8 ...)
    echo   [3] Google Gemini    (gemini-1.5-pro, gemini-1.5-flash ...)
    echo   [4] Azure OpenAI     (azure-hosted OpenAI deployments)
    echo   [5] Ollama           (local models, no API key needed)
    echo   [6] Generic / Other  (custom base URL)
    echo.
    set /p "PROVIDER_CHOICE= [?] Enter choice [1-6]: "

    if "!PROVIDER_CHOICE!"=="1" (
        set "LLM_PROVIDER=openai"
        set "PROVIDER_LABEL=OpenAI"
        set "DEFAULT_MODEL=gpt-4o"
    ) else if "!PROVIDER_CHOICE!"=="2" (
        set "LLM_PROVIDER=anthropic"
        set "PROVIDER_LABEL=Anthropic"
        set "DEFAULT_MODEL=claude-sonnet-4-6"
    ) else if "!PROVIDER_CHOICE!"=="3" (
        set "LLM_PROVIDER=gemini"
        set "PROVIDER_LABEL=Google Gemini"
        set "DEFAULT_MODEL=gemini-1.5-pro"
    ) else if "!PROVIDER_CHOICE!"=="4" (
        set "LLM_PROVIDER=azure"
        set "PROVIDER_LABEL=Azure OpenAI"
        set "DEFAULT_MODEL=gpt-4o"
        call :prompt_azure_extras
    ) else if "!PROVIDER_CHOICE!"=="5" (
        set "LLM_PROVIDER=ollama"
        set "PROVIDER_LABEL=Ollama (local)"
        set "DEFAULT_MODEL=llama3"
        set "SKIP_API_KEY=1"
    ) else if "!PROVIDER_CHOICE!"=="6" (
        set "LLM_PROVIDER=generic-openai"
        set "PROVIDER_LABEL=Generic / Other"
        set "DEFAULT_MODEL=gpt-4o"
        call :prompt_generic_extras
    ) else (
        echo  !RED![!] Invalid choice. Defaulting to OpenAI.!RESET!
        set "LLM_PROVIDER=openai"
        set "PROVIDER_LABEL=OpenAI"
        set "DEFAULT_MODEL=gpt-4o"
    )
    echo.
    goto :eof

:: -------------------------------------------------------
:prompt_azure_extras
    set /p "AZURE_ENDPOINT= [?] Azure endpoint URL (e.g. https://xyz.openai.azure.com/): "
    set /p "AZURE_DEPLOYMENT= [?] Deployment name: "
    set /p "AZURE_API_VERSION= [?] API version (e.g. 2024-02-15-preview): "
    goto :eof

:: -------------------------------------------------------
:prompt_generic_extras
    set /p "GENERIC_BASE_URL= [?] Base URL (e.g. http://localhost:8080/v1): "
    goto :eof

:: -------------------------------------------------------
:prompt_api_key
    if defined SKIP_API_KEY (
        set "USER_API_KEY=ollama-local"
        goto :eof
    )

    echo  !YELLOW!--- API Key -------------------------------------------------------!RESET!
    echo.

    :: Use PowerShell to hide key input if available, fall back to plain SET /P
    where powershell >nul 2>&1
    if !errorlevel! equ 0 (
        echo   (input will be hidden)
        for /f "delims=" %%K in ('powershell -NoProfile -Command ^
            "$k = Read-Host -AsSecureString ' [?] Enter your !PROVIDER_LABEL! API key'; ^
             $p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($k)); ^
             Write-Output $p"') do set "USER_API_KEY=%%K"
    ) else (
        set /p "USER_API_KEY= [?] Enter your !PROVIDER_LABEL! API key: "
    )

    if "!USER_API_KEY!"=="" (
        echo  !RED![!] API key cannot be empty.!RESET!
        goto :prompt_api_key
    )
    echo  !GREEN![+] API key accepted.!RESET!
    echo.
    goto :eof

:: -------------------------------------------------------
:prompt_model_id
    echo  !YELLOW!--- Model ID ------------------------------------------------------!RESET!
    echo.
    echo   Default for !PROVIDER_LABEL!: !DEFAULT_MODEL!
    set /p "USER_MODEL_ID= [?] Enter model ID (leave blank for default): "
    if "!USER_MODEL_ID!"=="" set "USER_MODEL_ID=!DEFAULT_MODEL!"
    echo  !GREEN![+] Model set to: !USER_MODEL_ID!!RESET!
    echo.
    goto :eof

:: -------------------------------------------------------
:prompt_save_config
    set /p "SAVE_CONF= [?] Save these settings for next time? (y/N): "
    if /i "!SAVE_CONF!"=="y" call :save_config
    echo.
    goto :eof

:: -------------------------------------------------------
:save_config
    (
        echo LLM_PROVIDER=!LLM_PROVIDER!
        echo PROVIDER_LABEL=!PROVIDER_LABEL!
        echo USER_API_KEY=!USER_API_KEY!
        echo USER_MODEL_ID=!USER_MODEL_ID!
        if defined AZURE_ENDPOINT      echo AZURE_ENDPOINT=!AZURE_ENDPOINT!
        if defined AZURE_DEPLOYMENT    echo AZURE_DEPLOYMENT=!AZURE_DEPLOYMENT!
        if defined AZURE_API_VERSION   echo AZURE_API_VERSION=!AZURE_API_VERSION!
        if defined GENERIC_BASE_URL    echo GENERIC_BASE_URL=!GENERIC_BASE_URL!
    ) > "%CONFIG_FILE%"
    echo  !GREEN![+] Configuration saved to anythingllm.config!RESET!
    goto :eof

:: -------------------------------------------------------
:load_config
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
        set "%%A=%%B"
    )
    echo  !GREEN![+] Loaded: Provider=!PROVIDER_LABEL!  Model=!USER_MODEL_ID!!RESET!
    echo.
    goto :eof

:: -------------------------------------------------------
:confirm_and_launch
    echo  !YELLOW!--- Confirm Settings ----------------------------------------------!RESET!
    echo.
    echo   Provider : !PROVIDER_LABEL!
    echo   Model    : !USER_MODEL_ID!
    echo   API Key  : ****************************
    echo.
    set /p "CONFIRM= [?] Launch with these settings? (Y/n): "
    if /i "!CONFIRM!"=="n" (
        call :main
        goto :eof
    )
    call :launch
    goto :eof

:: -------------------------------------------------------
:launch
    echo.
    echo  !CYAN!--- Applying Environment Variables ---------------------------------!RESET!

    :: Set provider
    set "LLM_PROVIDER=!LLM_PROVIDER!"

    :: Set provider-specific API key env var
    if "!LLM_PROVIDER!"=="openai"       set "OPENAI_API_KEY=!USER_API_KEY!"
    if "!LLM_PROVIDER!"=="anthropic"    set "ANTHROPIC_API_KEY=!USER_API_KEY!"
    if "!LLM_PROVIDER!"=="gemini"       set "GEMINI_API_KEY=!USER_API_KEY!"
    if "!LLM_PROVIDER!"=="azure"        set "AZURE_OPENAI_API_KEY=!USER_API_KEY!"
    if "!LLM_PROVIDER!"=="generic-openai" set "GENERIC_OPEN_AI_API_KEY=!USER_API_KEY!"

    :: Set model preference
    set "LLM_MODEL_PREFERENCE=!USER_MODEL_ID!"

    :: Azure-specific extras
    if defined AZURE_ENDPOINT    set "AZURE_OPENAI_ENDPOINT=!AZURE_ENDPOINT!"
    if defined AZURE_DEPLOYMENT  set "AZURE_OPENAI_DEPLOYMENT_NAME=!AZURE_DEPLOYMENT!"
    if defined AZURE_API_VERSION set "AZURE_OPENAI_API_VERSION=!AZURE_API_VERSION!"

    :: Generic / Ollama extras
    if defined GENERIC_BASE_URL  set "GENERIC_OPEN_AI_BASE_PATH=!GENERIC_BASE_URL!"
    if "!LLM_PROVIDER!"=="ollama" (
        if not defined OLLAMA_BASE_PATH set "OLLAMA_BASE_PATH=http://127.0.0.1:11434"
    )

    echo  !GREEN![+] Environment ready.!RESET!
    echo.

    :: ---- Locate AnythingLLM installation ----
    call :find_anythingllm
    if "!ANYTHINGLLM_DIR!"=="" (
        echo  !RED![!] AnythingLLM installation not found.!RESET!
        call :install_prompt
        goto :eof
    )

    echo  !CYAN![>] Starting AnythingLLM from: !ANYTHINGLLM_DIR!!RESET!
    echo  !CYAN![>] Open your browser at http://localhost:3001 once ready.!RESET!
    echo.

    :: Try yarn first, then node, then npm
    pushd "!ANYTHINGLLM_DIR!\server"
    where yarn >nul 2>&1 && (
        echo  !GREEN![+] Launching with yarn ...!RESET!
        yarn start
        goto :after_launch
    )
    where node >nul 2>&1 && (
        echo  !GREEN![+] Launching with node ...!RESET!
        node index.js
        goto :after_launch
    )
    where npm >nul 2>&1 && (
        echo  !GREEN![+] Launching with npm ...!RESET!
        npm start
        goto :after_launch
    )
    echo  !RED![!] Could not find yarn, node, or npm.  Please install Node.js.!RESET!
    :after_launch
    popd
    goto :eof

:: -------------------------------------------------------
:find_anythingllm
    set "ANYTHINGLLM_DIR="

    :: Check env var first
    if defined ANYTHINGLLM_PATH (
        if exist "!ANYTHINGLLM_PATH!\server\index.js" (
            set "ANYTHINGLLM_DIR=!ANYTHINGLLM_PATH!"
            goto :eof
        )
    )

    :: Common install locations
    for %%P in (
        "%~dp0"
        "%~dp0anythingllm"
        "%USERPROFILE%\anythingllm"
        "%USERPROFILE%\AppData\Local\AnythingLLM"
        "C:\AnythingLLM"
        "C:\Program Files\AnythingLLM"
    ) do (
        if exist "%%~P\server\index.js" (
            set "ANYTHINGLLM_DIR=%%~P"
            goto :eof
        )
    )
    goto :eof

:: -------------------------------------------------------
:install_prompt
    echo  !YELLOW!To install AnythingLLM, visit:!RESET!
    echo    https://github.com/Mintplex-Labs/anything-llm
    echo.
    echo  !YELLOW!Or place AnythingLLM next to this script in a folder named 'anythingllm'.!RESET!
    echo  !YELLOW!You can also set the ANYTHINGLLM_PATH environment variable.!RESET!
    echo.
    set /p "CUSTOM_DIR= [?] Enter path to AnythingLLM folder (or press Enter to exit): "
    if "!CUSTOM_DIR!"=="" goto :eof
    if exist "!CUSTOM_DIR!\server\index.js" (
        set "ANYTHINGLLM_DIR=!CUSTOM_DIR!"
        call :launch
    ) else (
        echo  !RED![!] No AnythingLLM server found at that path.!RESET!
    )
    goto :eof

:: -------------------------------------------------------
:set_colors
    :: ANSI escape codes (requires Windows 10 1511+ virtual terminal)
    for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
    set "RED=!ESC![91m"
    set "GREEN=!ESC![92m"
    set "YELLOW=!ESC![93m"
    set "CYAN=!ESC![96m"
    set "RESET=!ESC![0m"
    goto :eof

#Requires -Version 5.1
<#
.SYNOPSIS
    AnythingLLM PowerShell Launcher — prompts for API key and model ID, then starts AnythingLLM.
.DESCRIPTION
    Interactive launcher that securely collects credentials, persists them
    to an encrypted config file, sets the required environment variables,
    and starts the AnythingLLM server.
.EXAMPLE
    .\launch_anythingllm.ps1
.EXAMPLE
    .\launch_anythingllm.ps1 -Provider anthropic -ModelId claude-sonnet-4-6
#>
[CmdletBinding()]
param(
    [string]$Provider,
    [string]$ModelId,
    [string]$AnythingLLMPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
function Write-Header {
    $lines = @(
        "==============================================================",
        "  _              _   _     _             _     _     __  __  ",
        " / \  _ __  _   | |_| |__ (_)_ __   __ _| |   | |   |  \/  |",
        "/ _ \| '_ \| | | | __| '_ \| | '_ \ / _\` | |   | |   | |\/| |",
        "/ ___ \ | | | |_| | |_| | | | | | | | (_| | |___| |___| |  | |",
        "/_/   \_\_| |_|\__, |\__|_| |_|_|_| |_|\__, |_____|_____|_|  |_|",
        "               |___/                   |___/                    ",
        "=============================================================="
    )
    Write-Host ""
    foreach ($line in $lines) { Write-Host "  $line" -ForegroundColor Cyan }
    Write-Host "  Batch Launcher v1.0  --  API Key & Model Configurator" -ForegroundColor Yellow
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Read-MenuChoice {
    param([string]$Prompt, [int]$Min = 1, [int]$Max)
    do {
        $raw = Read-Host $Prompt
        $val = 0
        $ok  = [int]::TryParse($raw, [ref]$val) -and $val -ge $Min -and $val -le $Max
        if (-not $ok) { Write-Host "  Please enter a number between $Min and $Max." -ForegroundColor Red }
    } until ($ok)
    return $val
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $true)
    $hint = if ($Default) { "Y/n" } else { "y/N" }
    $raw  = Read-Host "$Prompt [$hint]"
    if ($raw -eq '') { return $Default }
    return $raw -imatch '^y'
}

# ------------------------------------------------------------------
# Provider catalogue
# ------------------------------------------------------------------
$PROVIDERS = @(
    [pscustomobject]@{ Id='openai';       Label='OpenAI';        EnvKey='OPENAI_API_KEY';            DefaultModel='gpt-4o';              NeedsKey=$true  }
    [pscustomobject]@{ Id='anthropic';    Label='Anthropic';     EnvKey='ANTHROPIC_API_KEY';         DefaultModel='claude-sonnet-4-6';   NeedsKey=$true  }
    [pscustomobject]@{ Id='gemini';       Label='Google Gemini'; EnvKey='GEMINI_API_KEY';            DefaultModel='gemini-1.5-pro';      NeedsKey=$true  }
    [pscustomobject]@{ Id='azure';        Label='Azure OpenAI';  EnvKey='AZURE_OPENAI_API_KEY';      DefaultModel='gpt-4o';              NeedsKey=$true  }
    [pscustomobject]@{ Id='ollama';       Label='Ollama (local)';EnvKey='';                          DefaultModel='llama3';              NeedsKey=$false }
    [pscustomobject]@{ Id='generic-openai';Label='Generic / Other';EnvKey='GENERIC_OPEN_AI_API_KEY';DefaultModel='gpt-4o';              NeedsKey=$true  }
)

# ------------------------------------------------------------------
# Config persistence (DPAPI encryption, Windows-only)
# ------------------------------------------------------------------
$CONFIG_PATH = Join-Path $PSScriptRoot "anythingllm.config.json"

function Save-Config {
    param($Cfg)
    $plain  = $Cfg | ConvertTo-Json -Depth 5
    $secure = ConvertTo-SecureString $plain -AsPlainText -Force
    $enc    = ConvertFrom-SecureString $secure
    Set-Content -Path $CONFIG_PATH -Value $enc -Encoding UTF8
    Write-Host "  [+] Settings saved (encrypted) to anythingllm.config.json" -ForegroundColor Green
}

function Load-Config {
    if (-not (Test-Path $CONFIG_PATH)) { return $null }
    try {
        $enc    = Get-Content $CONFIG_PATH -Raw
        $secure = ConvertTo-SecureString $enc
        $plain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                      [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        return $plain | ConvertFrom-Json
    } catch {
        Write-Host "  [!] Could not decrypt saved config (may belong to a different user). Ignoring." -ForegroundColor Yellow
        return $null
    }
}

# ------------------------------------------------------------------
# Input collection
# ------------------------------------------------------------------
function Select-Provider {
    Write-Host "  --- Select LLM Provider -------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $PROVIDERS.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $PROVIDERS[$i].Label)
    }
    Write-Host ""
    $choice = Read-MenuChoice " [?] Enter choice" -Max $PROVIDERS.Count
    return $PROVIDERS[$choice - 1]
}

function Get-ApiKey {
    param($ProviderLabel)
    Write-Host ""
    Write-Host "  --- API Key (input hidden) ----------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    do {
        $sec = Read-Host " [?] Enter your $ProviderLabel API key" -AsSecureString
        if ($sec.Length -eq 0) {
            Write-Host "  [!] API key cannot be empty." -ForegroundColor Red
        }
    } until ($sec.Length -gt 0)
    return $sec
}

function Get-ModelId {
    param($DefaultModel, $ProviderLabel)
    Write-Host ""
    Write-Host "  --- Model ID -------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  Default for ${ProviderLabel}: $DefaultModel"
    Write-Host ""
    $input = Read-Host " [?] Enter model ID (blank = default)"
    return if ($input -eq '') { $DefaultModel } else { $input }
}

function Get-AzureExtras {
    $extras = @{}
    $extras.Endpoint    = Read-Host " [?] Azure endpoint (e.g. https://xyz.openai.azure.com/)"
    $extras.Deployment  = Read-Host " [?] Deployment name"
    $extras.ApiVersion  = Read-Host " [?] API version (e.g. 2024-02-15-preview)"
    return $extras
}

function Get-GenericExtras {
    $extras = @{}
    $extras.BaseUrl = Read-Host " [?] Base URL (e.g. http://localhost:8080/v1)"
    return $extras
}

# ------------------------------------------------------------------
# Env-var application
# ------------------------------------------------------------------
function Apply-EnvVars {
    param($Prov, [securestring]$ApiKeySec, $ModelId, $Extras)

    $plain = if ($ApiKeySec -and $ApiKeySec.Length -gt 0) {
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKeySec))
    } else { '' }

    $env:LLM_PROVIDER          = $Prov.Id
    $env:LLM_MODEL_PREFERENCE  = $ModelId

    if ($Prov.EnvKey -ne '' -and $plain -ne '') {
        [System.Environment]::SetEnvironmentVariable($Prov.EnvKey, $plain, 'Process')
    }

    switch ($Prov.Id) {
        'azure' {
            $env:AZURE_OPENAI_ENDPOINT        = $Extras.Endpoint
            $env:AZURE_OPENAI_DEPLOYMENT_NAME = $Extras.Deployment
            $env:AZURE_OPENAI_API_VERSION     = $Extras.ApiVersion
        }
        'generic-openai' {
            $env:GENERIC_OPEN_AI_BASE_PATH = $Extras.BaseUrl
        }
        'ollama' {
            if (-not $env:OLLAMA_BASE_PATH) { $env:OLLAMA_BASE_PATH = 'http://127.0.0.1:11434' }
        }
    }

    Write-Host "  [+] Environment variables applied." -ForegroundColor Green
}

# ------------------------------------------------------------------
# AnythingLLM discovery & launch
# ------------------------------------------------------------------
function Find-AnythingLLM {
    param([string]$Hint)
    $candidates = @(
        $Hint,
        $PSScriptRoot,
        (Join-Path $PSScriptRoot 'anythingllm'),
        (Join-Path $HOME 'anythingllm'),
        (Join-Path $env:LOCALAPPDATA 'AnythingLLM'),
        'C:\AnythingLLM',
        'C:\Program Files\AnythingLLM'
    ) | Where-Object { $_ -ne '' }

    foreach ($p in $candidates) {
        $server = Join-Path $p 'server\index.js'
        if (Test-Path $server) { return $p }
    }
    return $null
}

function Start-AnythingLLM {
    param([string]$Dir)
    $serverDir = Join-Path $Dir 'server'
    Push-Location $serverDir

    Write-Host ""
    Write-Host "  [>] Starting AnythingLLM from: $Dir" -ForegroundColor Cyan
    Write-Host "  [>] Open your browser at http://localhost:3001 once ready." -ForegroundColor Cyan
    Write-Host ""

    $launched = $false
    foreach ($cmd in @('yarn', 'node', 'npm')) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $args = if ($cmd -eq 'node') { 'index.js' } else { 'start' }
            Write-Host "  [+] Launching with $cmd ..." -ForegroundColor Green
            & $cmd $args
            $launched = $true
            break
        }
    }

    Pop-Location

    if (-not $launched) {
        Write-Host ""
        Write-Host "  [!] Could not find yarn, node, or npm. Please install Node.js:" -ForegroundColor Red
        Write-Host "      https://nodejs.org/" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
Write-Header

# --- Check for saved config ---
$cfg = Load-Config
$provObj   = $null
$apiKeySec = $null
$modelId   = ''
$extras    = @{}

if ($cfg) {
    Write-Host "  [*] Saved configuration detected." -ForegroundColor Cyan
    $useSaved = Read-YesNo " [?] Use saved settings?" -Default $true
    if ($useSaved) {
        $provObj = $PROVIDERS | Where-Object { $_.Id -eq $cfg.ProviderId } | Select-Object -First 1
        if (-not $provObj) { $provObj = $PROVIDERS[0] }
        $modelId   = $cfg.ModelId
        # Rebuild SecureString from saved (plaintext stored in secure blob)
        if ($cfg.ApiKeyPlain -and $cfg.ApiKeyPlain -ne '') {
            $apiKeySec = ConvertTo-SecureString $cfg.ApiKeyPlain -AsPlainText -Force
        }
        if ($cfg.Extras) { $extras = $cfg.Extras }
        Write-Host ("  [+] Loaded: Provider={0}  Model={1}" -f $provObj.Label, $modelId) -ForegroundColor Green
        Write-Host ""
    }
}

# --- Collect inputs if not loaded from config ---
if (-not $provObj) {
    # Allow CLI params to skip interactive prompts
    if ($Provider) {
        $provObj = $PROVIDERS | Where-Object { $_.Id -eq $Provider } | Select-Object -First 1
        if (-not $provObj) {
            Write-Host "  [!] Unknown provider '$Provider'. Falling back to interactive selection." -ForegroundColor Yellow
        }
    }
    if (-not $provObj) { $provObj = Select-Provider }

    if ($provObj.NeedsKey) {
        $apiKeySec = Get-ApiKey -ProviderLabel $provObj.Label
    }

    if ($provObj.Id -eq 'azure')         { $extras = Get-AzureExtras }
    if ($provObj.Id -eq 'generic-openai') { $extras = Get-GenericExtras }

    $modelId = if ($ModelId) { $ModelId } else { Get-ModelId -DefaultModel $provObj.DefaultModel -ProviderLabel $provObj.Label }

    # Offer to save
    Write-Host ""
    if (Read-YesNo " [?] Save these settings for next time?" -Default $false) {
        $plainForSave = ''
        if ($apiKeySec -and $apiKeySec.Length -gt 0) {
            $plainForSave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeySec))
        }
        Save-Config @{
            ProviderId  = $provObj.Id
            ModelId     = $modelId
            ApiKeyPlain = $plainForSave
            Extras      = $extras
        }
    }
}

# --- Apply env vars ---
Write-Host ""
Write-Host "  --- Applying Environment Variables ---------------------------------" -ForegroundColor Cyan
Apply-EnvVars -Prov $provObj -ApiKeySec $apiKeySec -ModelId $modelId -Extras $extras

# --- Locate AnythingLLM ---
$hint = if ($AnythingLLMPath) { $AnythingLLMPath } elseif ($env:ANYTHINGLLM_PATH) { $env:ANYTHINGLLM_PATH } else { '' }
$dir  = Find-AnythingLLM -Hint $hint

if (-not $dir) {
    Write-Host ""
    Write-Host "  [!] AnythingLLM installation not found." -ForegroundColor Red
    Write-Host "  To install, visit: https://github.com/Mintplex-Labs/anything-llm" -ForegroundColor Yellow
    Write-Host "  Or place AnythingLLM next to this script in a folder named 'anythingllm'," -ForegroundColor Yellow
    Write-Host "  or pass -AnythingLLMPath <path> when running this script." -ForegroundColor Yellow
    Write-Host ""
    $custom = Read-Host " [?] Enter path to AnythingLLM folder (blank to exit)"
    if ($custom -eq '') { exit 1 }
    if (-not (Test-Path (Join-Path $custom 'server\index.js'))) {
        Write-Host "  [!] No AnythingLLM server found at that path." -ForegroundColor Red
        exit 1
    }
    $dir = $custom
}

Start-AnythingLLM -Dir $dir

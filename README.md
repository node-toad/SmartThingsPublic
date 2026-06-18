# AnythingLLM Batch Launcher

Interactive Windows launcher that prompts for your **API key** and **model ID**, sets
the required environment variables, and starts the [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) server.

---

## Files

| File | Purpose |
|------|---------|
| `launch_anythingllm.bat` | Primary launcher (Command Prompt) |
| `launch_anythingllm.ps1` | PowerShell launcher (encrypted config, hidden key input) |
| `setup_anythingllm.bat` | One-time setup: checks prerequisites and clones AnythingLLM |

---

## Quick Start

### 1. Run setup (first time only)

```bat
setup_anythingllm.bat
```

Checks that Node.js and Git are installed, then clones AnythingLLM into the
`anythingllm\` sub-folder and installs its dependencies.

### 2. Launch

**Option A — Batch file (simpler)**

```bat
launch_anythingllm.bat
```

**Option B — PowerShell (recommended: hidden key input + encrypted saved config)**

```powershell
.\launch_anythingllm.ps1
```

Both scripts walk you through:

1. Choosing your LLM provider
2. Entering your API key
3. Choosing a model ID
4. Optionally saving settings for next time

Then they apply the environment variables and start AnythingLLM.
Open **http://localhost:3001** in your browser once the server is running.

---

## Supported Providers

| # | Provider | Required API Key env var |
|---|----------|--------------------------|
| 1 | OpenAI | `OPENAI_API_KEY` |
| 2 | Anthropic | `ANTHROPIC_API_KEY` |
| 3 | Google Gemini | `GEMINI_API_KEY` |
| 4 | Azure OpenAI | `AZURE_OPENAI_API_KEY` |
| 5 | Ollama (local) | *(no key needed)* |
| 6 | Generic / Other | `GENERIC_OPEN_AI_API_KEY` |

---

## AnythingLLM Location

The scripts look for AnythingLLM in the following locations (in order):

1. `ANYTHINGLLM_PATH` environment variable
2. Same folder as the script
3. `anythingllm\` sub-folder next to the script
4. `%USERPROFILE%\anythingllm`
5. `%LOCALAPPDATA%\AnythingLLM`
6. `C:\AnythingLLM`
7. `C:\Program Files\AnythingLLM`

You can also set `ANYTHINGLLM_PATH` permanently:

```bat
setx ANYTHINGLLM_PATH "C:\path\to\anythingllm"
```

---

## Saved Configuration

- **Batch launcher** saves settings to `anythingllm.config` (plain text, stored locally).
- **PowerShell launcher** saves settings to `anythingllm.config.json` encrypted with
  Windows DPAPI — only the current Windows user account can decrypt it.

To reset saved settings, delete the config file and re-run the launcher.

---

## Prerequisites

- Windows 10 / 11
- [Node.js 18+](https://nodejs.org/)
- [Git](https://git-scm.com/) *(only needed for `setup_anythingllm.bat`)*
- Yarn or npm (yarn is preferred; npm ships with Node.js)

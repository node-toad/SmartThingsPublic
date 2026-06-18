# AnythingLLM Launcher  —  Version 1.0

GUI desktop app + batch/PowerShell CLI launchers that collect your **API key** and
**model ID**, apply environment variables, and start/stop the
[AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) server.

---

## Files

| File | Purpose |
|------|---------|
| `run.bat` | **Start here** — launches the GUI (Python) or falls back to the CLI |
| `anythingllm_v1.py` | Python tkinter GUI app (stdlib only, no extra installs) |
| `launch_anythingllm.bat` | CLI launcher for Command Prompt |
| `launch_anythingllm.ps1` | CLI launcher for PowerShell (encrypted config, hidden key input) |
| `setup_anythingllm.bat` | One-time setup: checks prerequisites, clones AnythingLLM |

---

## Quick Start

### Step 1 — Setup (first time only)

```bat
setup_anythingllm.bat
```

Checks that Node.js and Git are installed, clones AnythingLLM into the
`anythingllm\` sub-folder, and installs its dependencies.

### Step 2 — Launch

```bat
run.bat
```

Opens the GUI if Python is installed, otherwise falls back to the CLI launcher.

---

## GUI App (`anythingllm_v1.py`)

![layout description below]

```
┌──────────────────────────────────────────────────────────┐
│  AnythingLLM Launcher  v1.0                              │
├──────────────────────────────────────────────────────────┤
│  Provider   [ OpenAI ▾ ]                                 │
│  API Key    [ ••••••••••••••••••••••  ] [ Show ]         │
│  Model ID   [ gpt-4o ▾ ]                                 │
│  Install Path [ C:\anythingllm      ] [ Browse ]         │
│  Server Port  [ 3001 ]                                   │
│  ☑ Remember settings                                     │
├──────────────────────────────────────────────────────────┤
│  [ ▶ Launch AnythingLLM ]  [ ■ Stop ]     ● Stopped      │
├──────────────────────────────────────────────────────────┤
│  Server Log                                   [ Clear ]  │
│  ╔════════════════════════════════════════════════════╗  │
│  ║ === Launching AnythingLLM (OpenAI) ...          ║  │
│  ╚════════════════════════════════════════════════════╝  │
└──────────────────────────────────────────────────────────┘
```

Features:
- Dark-themed tkinter UI (no extra packages needed — standard library only)
- Provider dropdown with per-provider model lists
- Masked API key field with Show/Hide toggle
- Azure-specific fields (endpoint, deployment, API version) shown when Azure is selected
- Generic/Other base-URL field shown when Generic provider is selected
- Browse button for AnythingLLM install path
- Real-time server log with colour-coded lines
- Start / Stop server controls
- Settings saved to `anythingllm_v1.json` (plain JSON, local to script)
- Auto-discovers AnythingLLM in common install locations on startup

---

## Supported Providers

| Provider | API key env var set |
|----------|---------------------|
| OpenAI | `OPENAI_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY` + endpoint/deployment/version |
| Ollama (local) | *(no key needed)* |
| Generic / Other | `GENERIC_OPEN_AI_API_KEY` + base URL |

---

## AnythingLLM Discovery Order

The app looks for AnythingLLM in this order:

1. Path entered in the Install Path field (or saved config)
2. Same folder as the script
3. `anythingllm\` sub-folder next to the script
4. `%USERPROFILE%\anythingllm`
5. `%LOCALAPPDATA%\AnythingLLM`
6. `C:\AnythingLLM`
7. `C:\Program Files\AnythingLLM`
8. `ANYTHINGLLM_PATH` environment variable

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Windows 10 / 11 | (Linux/macOS work for the Python app) |
| [Node.js 18+](https://nodejs.org/) | Required to run AnythingLLM |
| [Python 3.8+](https://python.org/) | Required for the GUI app (`run.bat` falls back to CLI if absent) |
| [Git](https://git-scm.com/) | Only needed for `setup_anythingllm.bat` |
| yarn or npm | yarn preferred; npm ships with Node.js |

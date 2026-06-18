"""
AnythingLLM Launcher  —  Version 1.0
GUI desktop app (tkinter, stdlib only) that collects API key + model ID,
applies environment variables, and starts/stops the AnythingLLM server.
"""

import json
import os
import platform
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
APP_TITLE   = "AnythingLLM Launcher"
APP_VERSION = "v1.0"
CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "anythingllm_v1.json")
WIN = platform.system() == "Windows"

PROVIDERS = [
    {
        "id":            "openai",
        "label":         "OpenAI",
        "env_key":       "OPENAI_API_KEY",
        "needs_key":     True,
        "default_model": "gpt-4o",
        "models": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4",
                   "gpt-3.5-turbo", "o1", "o1-mini"],
    },
    {
        "id":            "anthropic",
        "label":         "Anthropic",
        "env_key":       "ANTHROPIC_API_KEY",
        "needs_key":     True,
        "default_model": "claude-sonnet-4-6",
        "models": ["claude-sonnet-4-6", "claude-opus-4-8", "claude-haiku-4-5-20251001",
                   "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022",
                   "claude-3-opus-20240229"],
    },
    {
        "id":            "gemini",
        "label":         "Google Gemini",
        "env_key":       "GEMINI_API_KEY",
        "needs_key":     True,
        "default_model": "gemini-1.5-pro",
        "models": ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-2.0-flash",
                   "gemini-2.5-pro"],
    },
    {
        "id":            "azure",
        "label":         "Azure OpenAI",
        "env_key":       "AZURE_OPENAI_API_KEY",
        "needs_key":     True,
        "default_model": "gpt-4o",
        "models": ["gpt-4o", "gpt-4-turbo", "gpt-35-turbo"],
    },
    {
        "id":            "ollama",
        "label":         "Ollama  (local — no key needed)",
        "env_key":       "",
        "needs_key":     False,
        "default_model": "llama3",
        "models": ["llama3", "llama3:70b", "mistral", "mixtral",
                   "phi3", "gemma2", "qwen2"],
    },
    {
        "id":            "generic-openai",
        "label":         "Generic / Other (OpenAI-compatible)",
        "env_key":       "GENERIC_OPEN_AI_API_KEY",
        "needs_key":     True,
        "default_model": "gpt-4o",
        "models": ["gpt-4o", "gpt-4", "gpt-3.5-turbo"],
    },
]

COLORS = {
    "bg":       "#1e1e2e",
    "panel":    "#2a2a3e",
    "border":   "#44475a",
    "accent":   "#7c6af7",
    "accent2":  "#50fa7b",
    "danger":   "#ff5555",
    "warning":  "#ffb86c",
    "text":     "#f8f8f2",
    "subtext":  "#6272a4",
    "log_bg":   "#12121e",
    "log_text": "#a9b7d0",
}

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------
def load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_config(data):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

# ---------------------------------------------------------------------------
# AnythingLLM discovery
# ---------------------------------------------------------------------------
SEARCH_PATHS = [
    os.path.dirname(os.path.abspath(__file__)),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "anythingllm"),
    os.path.expanduser("~/anythingllm"),
]
if WIN:
    SEARCH_PATHS += [
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "AnythingLLM"),
        r"C:\AnythingLLM",
        r"C:\Program Files\AnythingLLM",
    ]
else:
    SEARCH_PATHS += [
        "/opt/anythingllm",
        os.path.expanduser("~/.local/share/anythingllm"),
    ]

def find_anythingllm(hint=""):
    candidates = ([hint] if hint else []) + SEARCH_PATHS + (
        [os.environ.get("ANYTHINGLLM_PATH", "")] if os.environ.get("ANYTHINGLLM_PATH") else []
    )
    for p in candidates:
        if p and os.path.isfile(os.path.join(p, "server", "index.js")):
            return p
    return ""

# ---------------------------------------------------------------------------
# Main window
# ---------------------------------------------------------------------------
class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_TITLE}  {APP_VERSION}")
        self.resizable(True, True)
        self.minsize(700, 600)
        self.configure(bg=COLORS["bg"])

        self._cfg   = load_config()
        self._proc  = None        # server subprocess
        self._queue = queue.Queue()

        self._build_ui()
        self._load_saved_state()
        self._poll_log()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------
    def _build_ui(self):
        self._style()

        # Header
        hdr = tk.Frame(self, bg=COLORS["accent"], height=4)
        hdr.pack(fill=tk.X)

        title_frame = tk.Frame(self, bg=COLORS["bg"], pady=16)
        title_frame.pack(fill=tk.X, padx=24)
        tk.Label(title_frame, text=APP_TITLE, font=("Segoe UI", 20, "bold"),
                 fg=COLORS["text"], bg=COLORS["bg"]).pack(side=tk.LEFT)
        tk.Label(title_frame, text=APP_VERSION, font=("Segoe UI", 11),
                 fg=COLORS["subtext"], bg=COLORS["bg"]).pack(side=tk.LEFT, padx=8, pady=6)

        # Settings panel
        panel = tk.Frame(self, bg=COLORS["panel"], bd=0,
                         highlightthickness=1, highlightbackground=COLORS["border"])
        panel.pack(fill=tk.X, padx=24, pady=(0, 12))

        self._build_provider_row(panel)
        self._build_api_key_row(panel)
        self._build_model_row(panel)
        self._build_extras_frame(panel)
        self._build_path_row(panel)
        self._build_port_row(panel)
        self._build_save_row(panel)

        # Action buttons
        btn_frame = tk.Frame(self, bg=COLORS["bg"])
        btn_frame.pack(fill=tk.X, padx=24, pady=8)

        self.launch_btn = tk.Button(
            btn_frame, text="▶  Launch AnythingLLM",
            font=("Segoe UI", 12, "bold"),
            bg=COLORS["accent"], fg="white", activebackground="#6a5ae0",
            activeforeground="white", relief=tk.FLAT, cursor="hand2",
            padx=20, pady=10, command=self._launch,
        )
        self.launch_btn.pack(side=tk.LEFT, padx=(0, 8))

        self.stop_btn = tk.Button(
            btn_frame, text="■  Stop",
            font=("Segoe UI", 12, "bold"),
            bg=COLORS["danger"], fg="white", activebackground="#cc4444",
            activeforeground="white", relief=tk.FLAT, cursor="hand2",
            padx=20, pady=10, command=self._stop, state=tk.DISABLED,
        )
        self.stop_btn.pack(side=tk.LEFT)

        self.status_lbl = tk.Label(btn_frame, text="●  Stopped",
                                   font=("Segoe UI", 10),
                                   fg=COLORS["subtext"], bg=COLORS["bg"])
        self.status_lbl.pack(side=tk.RIGHT, padx=8)

        # Log
        log_hdr = tk.Frame(self, bg=COLORS["bg"])
        log_hdr.pack(fill=tk.X, padx=24, pady=(4, 0))
        tk.Label(log_hdr, text="Server Log", font=("Segoe UI", 10, "bold"),
                 fg=COLORS["subtext"], bg=COLORS["bg"]).pack(side=tk.LEFT)
        tk.Button(log_hdr, text="Clear", font=("Segoe UI", 9),
                  fg=COLORS["subtext"], bg=COLORS["bg"], bd=0, cursor="hand2",
                  command=self._clear_log).pack(side=tk.RIGHT)

        log_frame = tk.Frame(self, bg=COLORS["log_bg"],
                             highlightthickness=1, highlightbackground=COLORS["border"])
        log_frame.pack(fill=tk.BOTH, expand=True, padx=24, pady=(0, 16))

        self.log = tk.Text(log_frame, bg=COLORS["log_bg"], fg=COLORS["log_text"],
                           font=("Consolas", 10), bd=0, padx=8, pady=6,
                           state=tk.DISABLED, wrap=tk.WORD)
        sb = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.log.yview)
        self.log.configure(yscrollcommand=sb.set)
        sb.pack(side=tk.RIGHT, fill=tk.Y)
        self.log.pack(fill=tk.BOTH, expand=True)

        self.log.tag_config("info",    foreground=COLORS["log_text"])
        self.log.tag_config("ok",      foreground=COLORS["accent2"])
        self.log.tag_config("warn",    foreground=COLORS["warning"])
        self.log.tag_config("error",   foreground=COLORS["danger"])
        self.log.tag_config("heading", foreground=COLORS["accent"],
                            font=("Consolas", 10, "bold"))

    # row builders -------------------------------------------------------
    def _lbl(self, parent, text):
        tk.Label(parent, text=text, font=("Segoe UI", 10),
                 fg=COLORS["subtext"], bg=COLORS["panel"],
                 width=14, anchor=tk.W).pack(side=tk.LEFT, padx=(12, 4), pady=6)

    def _entry(self, parent, show=""):
        e = tk.Entry(parent, font=("Segoe UI", 10), show=show,
                     bg=COLORS["bg"], fg=COLORS["text"],
                     insertbackground=COLORS["text"],
                     relief=tk.FLAT, bd=0)
        e.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 12), ipady=5)
        return e

    def _build_provider_row(self, parent):
        row = tk.Frame(parent, bg=COLORS["panel"])
        row.pack(fill=tk.X)
        self._lbl(row, "Provider")
        self._provider_var = tk.StringVar()
        cb = ttk.Combobox(row, textvariable=self._provider_var, state="readonly",
                          font=("Segoe UI", 10),
                          values=[p["label"] for p in PROVIDERS])
        cb.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 12), ipady=3)
        cb.bind("<<ComboboxSelected>>", self._on_provider_change)

    def _build_api_key_row(self, parent):
        self._api_key_row = tk.Frame(parent, bg=COLORS["panel"])
        self._api_key_row.pack(fill=tk.X)
        self._lbl(self._api_key_row, "API Key")
        self._api_key_var  = tk.StringVar()
        self._api_key_show = tk.BooleanVar(value=False)
        self._api_key_entry = tk.Entry(
            self._api_key_row, textvariable=self._api_key_var,
            font=("Segoe UI", 10), show="•",
            bg=COLORS["bg"], fg=COLORS["text"],
            insertbackground=COLORS["text"], relief=tk.FLAT, bd=0,
        )
        self._api_key_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=5)
        tk.Checkbutton(self._api_key_row, text="Show", variable=self._api_key_show,
                       font=("Segoe UI", 9), fg=COLORS["subtext"],
                       bg=COLORS["panel"], activebackground=COLORS["panel"],
                       selectcolor=COLORS["panel"],
                       command=self._toggle_key_visibility).pack(side=tk.LEFT, padx=(4, 12))

    def _build_model_row(self, parent):
        row = tk.Frame(parent, bg=COLORS["panel"])
        row.pack(fill=tk.X)
        self._lbl(row, "Model ID")
        self._model_var = tk.StringVar()
        self._model_cb  = ttk.Combobox(row, textvariable=self._model_var,
                                        font=("Segoe UI", 10))
        self._model_cb.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 12), ipady=3)

    def _build_extras_frame(self, parent):
        self._extras_frame = tk.Frame(parent, bg=COLORS["panel"])
        self._extras_frame.pack(fill=tk.X)

        # Azure fields
        self._azure_frame = tk.Frame(self._extras_frame, bg=COLORS["panel"])
        r1 = tk.Frame(self._azure_frame, bg=COLORS["panel"])
        r1.pack(fill=tk.X)
        self._lbl(r1, "Azure Endpoint")
        self._azure_endpoint = self._entry(r1)
        r2 = tk.Frame(self._azure_frame, bg=COLORS["panel"])
        r2.pack(fill=tk.X)
        self._lbl(r2, "Deployment")
        self._azure_deployment = self._entry(r2)
        r3 = tk.Frame(self._azure_frame, bg=COLORS["panel"])
        r3.pack(fill=tk.X)
        self._lbl(r3, "API Version")
        self._azure_api_version = self._entry(r3)
        self._azure_api_version.insert(0, "2024-02-15-preview")

        # Generic base URL field
        self._generic_frame = tk.Frame(self._extras_frame, bg=COLORS["panel"])
        gr = tk.Frame(self._generic_frame, bg=COLORS["panel"])
        gr.pack(fill=tk.X)
        self._lbl(gr, "Base URL")
        self._generic_base_url = self._entry(gr)
        self._generic_base_url.insert(0, "http://localhost:8080/v1")

    def _build_path_row(self, parent):
        row = tk.Frame(parent, bg=COLORS["panel"])
        row.pack(fill=tk.X)
        self._lbl(row, "Install Path")
        self._path_var = tk.StringVar()
        tk.Entry(row, textvariable=self._path_var,
                 font=("Segoe UI", 10),
                 bg=COLORS["bg"], fg=COLORS["text"],
                 insertbackground=COLORS["text"],
                 relief=tk.FLAT, bd=0).pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=5)
        tk.Button(row, text="Browse",
                  font=("Segoe UI", 9), bg=COLORS["border"], fg=COLORS["text"],
                  activebackground=COLORS["accent"], activeforeground="white",
                  relief=tk.FLAT, padx=8, pady=4, cursor="hand2",
                  command=self._browse).pack(side=tk.LEFT, padx=(4, 12))

    def _build_port_row(self, parent):
        row = tk.Frame(parent, bg=COLORS["panel"])
        row.pack(fill=tk.X)
        self._lbl(row, "Server Port")
        self._port_var = tk.StringVar(value="3001")
        tk.Entry(row, textvariable=self._port_var, width=8,
                 font=("Segoe UI", 10),
                 bg=COLORS["bg"], fg=COLORS["text"],
                 insertbackground=COLORS["text"],
                 relief=tk.FLAT, bd=0).pack(side=tk.LEFT, ipady=5)
        tk.Label(row, text="(default 3001)",
                 font=("Segoe UI", 9), fg=COLORS["subtext"],
                 bg=COLORS["panel"]).pack(side=tk.LEFT, padx=8)

    def _build_save_row(self, parent):
        row = tk.Frame(parent, bg=COLORS["panel"])
        row.pack(fill=tk.X, pady=(4, 8))
        self._save_var = tk.BooleanVar(value=True)
        tk.Checkbutton(row, text="Remember settings",
                       variable=self._save_var,
                       font=("Segoe UI", 9), fg=COLORS["subtext"],
                       bg=COLORS["panel"], activebackground=COLORS["panel"],
                       selectcolor=COLORS["panel"]).pack(side=tk.LEFT, padx=12)

    # ------------------------------------------------------------------
    # ttk style
    # ------------------------------------------------------------------
    def _style(self):
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure("TCombobox",
                    fieldbackground=COLORS["bg"],
                    background=COLORS["bg"],
                    foreground=COLORS["text"],
                    selectbackground=COLORS["accent"],
                    selectforeground="white",
                    borderwidth=0)
        s.map("TCombobox",
              fieldbackground=[("readonly", COLORS["bg"])],
              foreground=[("readonly", COLORS["text"])])
        s.configure("TScrollbar",
                    background=COLORS["border"],
                    troughcolor=COLORS["log_bg"],
                    arrowcolor=COLORS["subtext"])

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------
    def _on_provider_change(self, _=None):
        p = self._current_provider()
        if not p:
            return

        # model list
        self._model_cb["values"] = p["models"]
        if self._model_var.get() not in p["models"]:
            self._model_var.set(p["default_model"])

        # API key row visibility
        if p["needs_key"]:
            self._api_key_row.pack(fill=tk.X)
        else:
            self._api_key_row.pack_forget()

        # extras
        self._azure_frame.pack_forget()
        self._generic_frame.pack_forget()
        if p["id"] == "azure":
            self._azure_frame.pack(fill=tk.X)
        elif p["id"] == "generic-openai":
            self._generic_frame.pack(fill=tk.X)

    def _toggle_key_visibility(self):
        self._api_key_entry.config(show="" if self._api_key_show.get() else "•")

    def _browse(self):
        path = filedialog.askdirectory(title="Select AnythingLLM folder")
        if path:
            self._path_var.set(path)

    # ------------------------------------------------------------------
    # Launch / Stop
    # ------------------------------------------------------------------
    def _launch(self):
        if self._proc and self._proc.poll() is None:
            self._log("Server is already running.", "warn")
            return

        p = self._current_provider()
        if not p:
            messagebox.showerror("Error", "Please select a provider.")
            return

        api_key  = self._api_key_var.get().strip()
        model_id = self._model_var.get().strip()
        port     = self._port_var.get().strip() or "3001"
        base_path = self._path_var.get().strip()

        if p["needs_key"] and not api_key:
            messagebox.showerror("Error", "API key is required for this provider.")
            return
        if not model_id:
            messagebox.showerror("Error", "Model ID cannot be empty.")
            return

        # Locate AnythingLLM
        install_dir = find_anythingllm(base_path)
        if not install_dir:
            messagebox.showerror(
                "Not Found",
                "AnythingLLM installation not found.\n\n"
                "Set the Install Path field or run setup_anythingllm.bat first.\n"
                "See README.md for details."
            )
            return

        # Build env
        env = os.environ.copy()
        env["LLM_PROVIDER"]         = p["id"]
        env["LLM_MODEL_PREFERENCE"] = model_id
        env["SERVER_PORT"]          = port
        if p["env_key"] and api_key:
            env[p["env_key"]] = api_key
        if p["id"] == "azure":
            env["AZURE_OPENAI_ENDPOINT"]        = self._azure_endpoint.get().strip()
            env["AZURE_OPENAI_DEPLOYMENT_NAME"] = self._azure_deployment.get().strip()
            env["AZURE_OPENAI_API_VERSION"]     = self._azure_api_version.get().strip()
        if p["id"] == "generic-openai":
            env["GENERIC_OPEN_AI_BASE_PATH"] = self._generic_base_url.get().strip()
        if p["id"] == "ollama" and "OLLAMA_BASE_PATH" not in env:
            env["OLLAMA_BASE_PATH"] = "http://127.0.0.1:11434"

        # Pick runtime
        server_dir = os.path.join(install_dir, "server")
        cmd = self._pick_runtime(server_dir)
        if not cmd:
            messagebox.showerror("Error",
                                 "Cannot find yarn, node, or npm.\nPlease install Node.js.")
            return

        # Save config
        if self._save_var.get():
            self._save_state(api_key)

        # Launch
        self._log(f"=== Launching AnythingLLM ({p['label']}) — model: {model_id} ===", "heading")
        self._log(f"    Install dir : {install_dir}", "info")
        self._log(f"    Runtime     : {' '.join(cmd)}", "info")
        self._log(f"    URL         : http://localhost:{port}", "ok")

        try:
            self._proc = subprocess.Popen(
                cmd,
                cwd=server_dir,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError as exc:
            self._log(f"Launch failed: {exc}", "error")
            return

        self._set_running(True)
        threading.Thread(target=self._stream_output, daemon=True).start()

    def _stop(self):
        if self._proc and self._proc.poll() is None:
            self._log("--- Stopping server ---", "warn")
            if WIN:
                self._proc.send_signal(__import__("signal").CTRL_BREAK_EVENT)
            else:
                self._proc.terminate()
        self._set_running(False)

    def _pick_runtime(self, server_dir):
        for exe, args in [("yarn", ["start"]), ("node", ["index.js"]), ("npm", ["start"])]:
            try:
                full = __import__("shutil").which(exe)
                if full:
                    return [full] + args
            except Exception:
                pass
        return None

    # ------------------------------------------------------------------
    # Output streaming
    # ------------------------------------------------------------------
    def _stream_output(self):
        for line in self._proc.stdout:
            self._queue.put(("info", line.rstrip()))
        ret = self._proc.wait()
        self._queue.put(("warn" if ret else "ok",
                         f"--- Process exited (code {ret}) ---"))
        self._queue.put(("_done", None))

    def _poll_log(self):
        try:
            while True:
                kind, msg = self._queue.get_nowait()
                if kind == "_done":
                    self.after(0, lambda: self._set_running(False))
                else:
                    self._log(msg, kind)
        except queue.Empty:
            pass
        self.after(100, self._poll_log)

    # ------------------------------------------------------------------
    # Log helpers
    # ------------------------------------------------------------------
    def _log(self, msg, kind="info"):
        self.log.configure(state=tk.NORMAL)
        self.log.insert(tk.END, msg + "\n", kind)
        self.log.see(tk.END)
        self.log.configure(state=tk.DISABLED)

    def _clear_log(self):
        self.log.configure(state=tk.NORMAL)
        self.log.delete("1.0", tk.END)
        self.log.configure(state=tk.DISABLED)

    # ------------------------------------------------------------------
    # State helpers
    # ------------------------------------------------------------------
    def _set_running(self, running):
        if running:
            self.launch_btn.configure(state=tk.DISABLED)
            self.stop_btn.configure(state=tk.NORMAL)
            self.status_lbl.configure(text="●  Running", fg=COLORS["accent2"])
        else:
            self.launch_btn.configure(state=tk.NORMAL)
            self.stop_btn.configure(state=tk.DISABLED)
            self.status_lbl.configure(text="●  Stopped", fg=COLORS["subtext"])

    def _current_provider(self):
        label = self._provider_var.get()
        return next((p for p in PROVIDERS if p["label"] == label), None)

    # ------------------------------------------------------------------
    # Config persistence
    # ------------------------------------------------------------------
    def _load_saved_state(self):
        c = self._cfg
        # provider
        labels = [p["label"] for p in PROVIDERS]
        saved_label = next(
            (p["label"] for p in PROVIDERS if p["id"] == c.get("provider_id")),
            labels[0]
        )
        self._provider_var.set(saved_label)
        self._on_provider_change()

        self._api_key_var.set(c.get("api_key", ""))
        if c.get("model"):
            self._model_var.set(c["model"])
        if c.get("path"):
            self._path_var.set(c["path"])
        else:
            discovered = find_anythingllm()
            if discovered:
                self._path_var.set(discovered)
        if c.get("port"):
            self._port_var.set(c["port"])
        if c.get("azure_endpoint"):
            self._azure_endpoint.delete(0, tk.END)
            self._azure_endpoint.insert(0, c["azure_endpoint"])
        if c.get("azure_deployment"):
            self._azure_deployment.delete(0, tk.END)
            self._azure_deployment.insert(0, c["azure_deployment"])
        if c.get("azure_api_version"):
            self._azure_api_version.delete(0, tk.END)
            self._azure_api_version.insert(0, c["azure_api_version"])
        if c.get("generic_base_url"):
            self._generic_base_url.delete(0, tk.END)
            self._generic_base_url.insert(0, c["generic_base_url"])

    def _save_state(self, api_key_plain):
        p = self._current_provider()
        save_config({
            "provider_id":       p["id"] if p else "",
            "api_key":           api_key_plain,
            "model":             self._model_var.get(),
            "path":              self._path_var.get(),
            "port":              self._port_var.get(),
            "azure_endpoint":    self._azure_endpoint.get(),
            "azure_deployment":  self._azure_deployment.get(),
            "azure_api_version": self._azure_api_version.get(),
            "generic_base_url":  self._generic_base_url.get(),
        })

    # ------------------------------------------------------------------
    # Close
    # ------------------------------------------------------------------
    def _on_close(self):
        if self._proc and self._proc.poll() is None:
            if messagebox.askyesno("Quit", "Server is running. Stop it and quit?"):
                self._stop()
                self.destroy()
        else:
            self.destroy()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app = App()
    app.mainloop()

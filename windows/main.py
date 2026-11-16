"""ItamarOS iPhone Studio for Windows — safe device manager prototype."""
import json
import os
import shutil
import subprocess
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox
import customtkinter as ctk

APP_DIR = Path(os.getenv("APPDATA", str(Path.home()))) / "ItamarOS" / "iPhoneStudio"
CONFIG = APP_DIR / "settings.json"
DEFAULT_BACKUP = str(Path.home() / "Documents" / "ItamarOS iPhone Studio" / "Backups")

def load_settings():
    try:
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"backup_enabled": True, "backup_path": DEFAULT_BACKUP}

def save_settings(data):
    APP_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(json.dumps(data, indent=2), encoding="utf-8")

def run_tool(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=15, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return str(exc)

class Studio(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("ItamarOS iPhone Studio — Windows")
        self.geometry("760x610")
        ctk.set_appearance_mode("dark")
        self.settings = load_settings()
        self.heading = ctk.CTkLabel(self, text="ItamarOS iPhone Studio", font=ctk.CTkFont(size=26, weight="bold"))
        self.heading.pack(pady=(22, 10))
        self.status = ctk.CTkTextbox(self, height=145)
        self.status.pack(fill="x", padx=24, pady=10)
        ctk.CTkButton(self, text="Detect iPhone (USB)", command=self.detect).pack(pady=5)
        ctk.CTkButton(self, text="Check Apple Mobile Device Service", command=self.service).pack(pady=5)
        ctk.CTkButton(self, text="Select IPSW (inspect only)", command=self.ipsw).pack(pady=5)
        ctk.CTkLabel(self, text="Local Backup Settings", font=ctk.CTkFont(size=18, weight="bold")).pack(pady=(18, 4))
        self.backup_var = tk.BooleanVar(value=self.settings.get("backup_enabled", True))
        ctk.CTkCheckBox(self, text="Enable local backup", variable=self.backup_var, command=self.persist).pack(pady=6)
        self.path_var = tk.StringVar(value=self.settings.get("backup_path", DEFAULT_BACKUP))
        ctk.CTkEntry(self, textvariable=self.path_var, width=590).pack(pady=5)
        ctk.CTkButton(self, text="Choose Backup Folder", command=self.choose_folder).pack(pady=5)
        ctk.CTkButton(self, text="Save Settings", command=self.persist).pack(pady=5)
        ctk.CTkLabel(self, text="Before system changes: Settings → Apple Account → iCloud → iCloud Backup → Back Up Now", wraplength=690).pack(pady=12)
        self.log("Connect an unlocked iPhone by USB and tap Trust on the device.\n")
        self.log("This version does not jailbreak, restore firmware, install IPA or create device backups.\n")

    def log(self, msg):
        self.status.insert("end", msg + "\n")
        self.status.see("end")

    def detect(self):
        def work():
            exe = shutil.which("ideviceinfo")
            if not exe:
                self.after(0, lambda: self.log("Device detection requires libimobiledevice's ideviceinfo in PATH. Apple drivers alone are not a device-info CLI."))
                return
            result = run_tool(exe, "-k", "ProductType")
            output = result.stdout.strip() if hasattr(result, "stdout") else str(result)
            self.after(0, lambda: self.log("Device: " + (output or "Not detected. Check USB cable, trust prompt and drivers.")))
        threading.Thread(target=work, daemon=True).start()

    def service(self):
        def work():
            result = run_tool("sc", "query", "Apple Mobile Device Service")
            output = result.stdout if hasattr(result, "stdout") else str(result)
            self.after(0, lambda: self.log(output.strip()[:1300] or "Service not found; check Apple Devices/iTunes installation."))
        threading.Thread(target=work, daemon=True).start()

    def ipsw(self):
        path = filedialog.askopenfilename(filetypes=[("iOS Firmware", "*.ipsw")])
        if path:
            self.log(f"Selected IPSW: {Path(path).name} ({Path(path).stat().st_size // (1024*1024)} MB)")
            messagebox.showinfo("Inspection only", "An IPSW filename does not prove Apple is signing it. No restore or downgrade will be performed.")

    def choose_folder(self):
        path = filedialog.askdirectory()
        if path:
            self.path_var.set(path)
            self.persist()

    def persist(self):
        self.settings = {"backup_enabled": self.backup_var.get(), "backup_path": self.path_var.get()}
        save_settings(self.settings)
        self.log("Backup preferences saved. This version does not yet execute backups.")

if __name__ == "__main__":
    Studio().mainloop()

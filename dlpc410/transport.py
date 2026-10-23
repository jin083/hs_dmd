"""TI DLL through 32-bit Windows PowerShell, plus an explicit command mock."""

import json
import os
from pathlib import Path
import subprocess


class PowerShellTransport:
    def __init__(self, *, device=0, dll_path=None, timeout_s=300):
        if type(device) is not int or not 0 <= device <= 32767:
            raise ValueError("device must be 0..32767")
        self.device = device
        self.dll_path = Path(dll_path).resolve() if dll_path else None
        self.timeout_s = timeout_s

    def invoke(self, action, plan=None):
        if os.name != "nt":
            raise RuntimeError("TI USB transport requires Windows; MockTransport works offline")
        if action not in {"Status", "Upload", "Configure", "Start", "Arm", "Stop"}:
            raise ValueError("Unsupported action")
        executable = Path(os.environ.get("WINDIR", "C:/Windows")) / "SysWOW64/WindowsPowerShell/v1.0/powershell.exe"
        command = [str(executable), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                   "-File", str(Path(__file__).with_name("dmd_playback.ps1")),
                   "-Action", action, "-Device", str(self.device)]
        if plan is not None:
            command += ["-Plan", str(Path(plan).resolve())]
        if self.dll_path:
            command += ["-DllPath", str(self.dll_path)]
        result = subprocess.run(command, capture_output=True, text=True, errors="replace",
                                timeout=self.timeout_s, check=False)
        if result.returncode:
            raise RuntimeError(f"{action} failed ({result.returncode}): {result.stderr.strip()} {result.stdout.strip()}")
        return json.loads(result.stdout) if action == "Status" else {"action": action, "output": result.stdout.strip()}


class MockTransport:
    """Command-flow fixture only: no DDR2, optics or µs timing simulation."""
    def __init__(self):
        self.calls = []
        self.count = 0
        self.plan = None
        self.done = False
        self.running = False
        self.armed = False
        self.accepted = 0

    def invoke(self, action, plan=None):
        payload = json.loads(Path(plan).read_text(encoding="utf-8")) if plan else None
        self.calls.append({"action": action, "plan": payload})
        if action in ("Upload", "Configure"):
            if action == "Upload":
                self.count = len(payload["patterns"])
            elif self.count != len(payload["patterns"]):
                raise RuntimeError("Mock requires matching upload first")
            self.plan = payload
            self.done = self.running = self.armed = False
        elif action in ("Start", "Arm"):
            if self.plan is None or not self.count:
                raise RuntimeError("Mock has no uploaded/configured patterns")
            self.armed = action == "Arm"
            # An external edge is generated immediately by the fixture, not by PC hardware.
            self.accepted += 1
            self.done = self.plan["repeat_count"] != 0
            self.running = not self.done
        elif action == "Stop":
            self.running = self.armed = False
        elif action == "Status":
            return {"Simulated": True, "Connected": True, "FPGA_ABI": "0xD201",
                    "UploadedPatterns": self.count, "Running": self.running,
                    "FrameBusy": False, "Done": self.done, "Error": False,
                    "Armed": self.armed, "AcceptedTriggers": self.accepted,
                    "CompletedLoops": self.plan["repeat_count"] if self.done else 0}
        else:
            raise ValueError(f"Unknown mock action: {action}")
        return {"action": action, "simulated": True}

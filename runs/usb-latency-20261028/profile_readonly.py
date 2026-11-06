"""One-off, read-only USB timing audit. No register writes or playback calls."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent


def child_profile():
    from dmd_ctrl.memory.native import _Usb64Device
    from dmd_ctrl.memory import Usb64Transport, PatternStore

    device = _Usb64Device(timeout_s=8)
    events = []
    for name in ("_load_dll", "_devices", "_read"):
        original = getattr(device, name)

        def timed(*args, _name=name, _original=original, **kwargs):
            started = time.perf_counter()
            value = _original(*args, **kwargs)
            events.append({"method": _name, "args": args,
                           "seconds": time.perf_counter() - started, "value": value})
            return value

        setattr(device, name, timed)
    direct = []
    try:
        for _ in range(3):
            started = time.perf_counter()
            status = device.invoke("Status")
            direct.append({"seconds": time.perf_counter()-started, "status": status})
            if not status.get("Connected"):
                break
    finally:
        device.close()
    transport = Usb64Transport(timeout_s=8)
    worker = []
    try:
        for _ in range(3):
            started = time.perf_counter()
            status = transport.invoke("Status")
            worker.append({"seconds": time.perf_counter()-started, "status": status})
            if not status.get("Connected"):
                break
        if status.get("FPGA_ABI") == "0xD202":
            started = time.perf_counter()
            status = PatternStore(transport).status()
            memory = {"seconds": time.perf_counter()-started, "status": status}
        else:
            memory = None
    finally:
        started = time.perf_counter()
        transport.close()
        close_s = time.perf_counter()-started
    return {"direct": direct, "native_calls": events, "worker": worker,
            "memory_status": memory, "worker_close_s": close_s}


def main():
    if "--child" in sys.argv:
        result = child_profile()
        (ROOT / "native_profile.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        return
    report = {"scope": "read-only status; no register writes, uploads, playback, JTAG or Flash",
              "python": sys.executable, "commands": []}
    commands = [
        ("python_startup", [sys.executable, "-c", "pass"]),
        ("cli_help", [sys.executable, "-m", "dmd_test", "--help"]),
        ("cli_simulated_status", [sys.executable, "-m", "dmd_test", "status", "--simulate", "--output", str(ROOT / "cli")]),
        ("cli_usb_status", [sys.executable, "-m", "dmd_test", "status", "--usb-timeout", "8", "--output", str(ROOT / "cli")]),
    ]
    for name, command in commands:
        for index in range(3):
            started = time.perf_counter()
            process = subprocess.run(command, capture_output=True, text=True, timeout=20)
            elapsed = time.perf_counter()-started
            entry = {"name": name, "repeat": index, "seconds": elapsed,
                     "returncode": process.returncode, "stdout": process.stdout, "stderr": process.stderr}
            report["commands"].append(entry)
            print(f"{name}[{index}]: {elapsed:.4f}s exit={process.returncode}", flush=True)
            (ROOT / "summary.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
            if process.returncode:
                raise RuntimeError(f"{name} failed; see saved report")
    process = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--child"],
                             capture_output=True, text=True, timeout=45)
    report["profile_child"] = {"returncode": process.returncode, "stdout": process.stdout, "stderr": process.stderr}
    if process.returncode == 0:
        report["profile"] = json.loads((ROOT / "native_profile.json").read_text(encoding="utf-8"))
    (ROOT / "summary.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report.get("profile", report["profile_child"]), indent=2))


if __name__ == "__main__":
    main()

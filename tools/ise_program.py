"""Program the pinned LX50 candidate from Windows using the installed ISE VM.

python tools/ise_program.py --check    # files/VM metadata only; no hardware calls
python tools/ise_program.py --program  # board powered on, Xilinx cable connected
Uses Python's standard library. Never writes the LX30 or a configuration PROM.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BIT = ROOT / "artifacts/dmd-20261026/appsfpga_repaired_jtag.bit"
EXPECTED_SHA256 = "48b42b1f260687d8cb05db0119f1b42282dc543090c3b60dde2baede5d7a120b"
VM = "ISE_14.7_VIRTUAL_MACHINE"
VBOX = Path(os.environ.get("PROGRAMFILES", "C:/Program Files")) / "Oracle/VirtualBox/VBoxManage.exe"


def vbox(*args, timeout=30):
    try:
        result = subprocess.run([str(VBOX), *args], capture_output=True, text=True,
                                errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError("VirtualBox command timed out; inspect the run logs before retrying.") from None
    if result.returncode:
        # Do not include the argv: guestcontrol contains the VM login password.
        raise RuntimeError((result.stderr or result.stdout).strip() or "VirtualBox command failed")
    return result.stdout


def metadata(text):
    return dict(re.findall(r'^([^=\r\n]+)=(.*)$', text, re.M))


def cable_attached(info):
    return any(value.strip('"').lower() == "0x03fd" and
               info.get(key.replace("VendorId", "ProductId"), "").strip('"').lower()
               in ("0x0008", "0x000d")
               for key, value in info.items() if key.startswith("USBAttachVendorId"))


def attach_cable(info):
    if cable_attached(info):
        return
    candidates = []
    for block in re.split(r"\r?\n\s*\r?\n", vbox("list", "usbhost")):
        if (re.search(r"VendorId:\s+0x03fd\b", block, re.I) and
                re.search(r"ProductId:\s+0x000(?:8|d)\b", block, re.I)):
            match = re.search(r"UUID:\s+([0-9a-f-]{36})", block, re.I)
            if match:
                candidates.append(match.group(1))
    if len(candidates) != 1:
        raise RuntimeError("Connect exactly one Xilinx Platform USB cable; leave the D4100 USB on Windows.")
    vbox("controlvm", VM, "usbattach", candidates[0])


def require_lx50_chain(cdf):
    parts = re.findall(r"PartName\s*\(\s*([^\s)]+)\s*\)", cdf, re.I)
    if [part.lower() for part in parts] != ["xc5vlx50", "xc5vlx30"]:
        raise RuntimeError(f"Unexpected JTAG chain {parts}; no programming attempted. Expected LX50 then LX30.")
    return parts


def verify_program_log(log):
    if not re.search(r"Programmed successfully", log, re.I):
        raise RuntimeError("iMPACT did not report successful programming; inspect program.log.")
    expected = {"Value of DONE pin": 1,
                "Internal signal indicates that chip is configured": 1,
                "End of startup signal from Startup block": 1,
                "CRC error": 0,
                "Indicates when ID value written does not match chip ID": 0,
                "read back crc error": 0}
    actual = {}
    for label, value in expected.items():
        matches = re.findall(r"^\s*" + re.escape(label) + r"\s*:\s*([01])\b", log, re.M)
        if not matches or int(matches[-1]) != value:
            raise RuntimeError(f"Missing/failed final status: {label}; inspect program.log.")
        actual[label] = int(matches[-1])
    return actual


def run_impact(folder, name, commands):
    (folder / (name + ".cmd")).write_bytes((commands + "\n").encode("ascii"))
    guest_folder = "/home/ise/C_DRIVE/" + folder.as_posix()[3:]
    script = ("#!/bin/bash\nset -eo pipefail\n"
              "source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n"
              "cd " + shlex.quote(guest_folder) + "\n"
              f"echo '{EXPECTED_SHA256}  {BIT.name}' | sha256sum -c - >/dev/null\n"
              f"impact -batch {name}.cmd > {name}.log 2>&1\n")
    (folder / (name + ".sh")).write_bytes(script.encode("utf-8"))
    vbox("guestcontrol", VM, "run", "--exe", "/bin/bash", "--username", "ise",
         "--password", os.environ.get("ISE_VM_PASSWORD", "xilinx"),
         "--timeout", "300000", "--wait-stdout", "--wait-stderr", "--",
         guest_folder + "/" + name + ".sh", timeout=330)


def program(info):
    folder = Path(tempfile.mkdtemp(prefix="dmd-jtag-"))
    if folder.drive.upper() != "C:":
        raise RuntimeError("The installed VM shares C:. Set Windows TEMP to a folder on C:.")
    print("Run logs:", folder, flush=True)
    shutil.copyfile(BIT, folder / BIT.name)
    if hashlib.sha256((folder / BIT.name).read_bytes()).hexdigest() != EXPECTED_SHA256:
        raise RuntimeError("Copied bitstream hash mismatch")
    record = {"bitstream_sha256": EXPECTED_SHA256, "stage": "prepared",
              "program_verified": False, "vm": VM, "target_position": 1}

    def save():
        (folder / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")

    save()
    try:
        attach_cable(info)
        print("Identifying JTAG chain...", flush=True)
        run_impact(folder, "identify", "setMode -bs\nsetCable -p auto\nIdentify\nsaveCdf -file chain.cdf\nquit")
        record["chain"] = require_lx50_chain((folder / "chain.cdf").read_text())
        record["stage"] = "programming"
        save()
        print("Programming LX50 position 1...", flush=True)
        run_impact(folder, "program", "setMode -bs\nsetCable -p auto\nIdentify\n"
                   "assignFile -p 1 -file " + BIT.name + "\nProgram -p 1\nReadStatusRegister -p 1\nquit")
        record["status"] = verify_program_log((folder / "program.log").read_text(errors="replace"))
        record.update(stage="verified", program_verified=True)
        print("LX50 programmed; DONE=1, startup complete, CRC/ID errors=0.")
        print("Press and release SW2, then run dmd-test status, upload and show --number 1 on Windows.")
    except Exception as exc:
        record["error"] = str(exc)
        raise
    finally:
        save()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", action="store_true", help="VM metadata and file check only (default)")
    action.add_argument("--program", action="store_true", help="Actually program the powered LX50 via JTAG")
    args = parser.parse_args(argv)
    try:
        if os.name != "nt":
            raise RuntimeError("Run this helper in Windows PowerShell with the existing Python installation.")
        if hashlib.sha256(BIT.read_bytes()).hexdigest() != EXPECTED_SHA256:
            raise RuntimeError("Candidate bitstream hash mismatch; no programming attempted.")
        info = metadata(vbox("showvminfo", VM, "--machinereadable"))
        print("VM state:", info.get("VMState"), "session:", info.get("SessionName"))
        print("Xilinx cable attached to VM:", cable_attached(info))
        print("Bitstream:", BIT)
        print("SHA256:", EXPECTED_SHA256)
        if not args.program:
            print("Check only: no USB/JTAG device calls and no VM changes.")
            return 0
        if info.get("VMState") != '"running"':
            raise RuntimeError("ISE VM must already be running. No VM/security settings were changed.")
        if not any(key.startswith("SharedFolderName") and value == '"C_DRIVE"' and
                   info.get(key.replace("Name", "Path"), "").strip('"').replace("\\\\", "\\").lower()
                   == "c:\\" for key, value in info.items()):
            raise RuntimeError("The ISE VM needs its existing C_DRIVE shared folder.")
        program(info)
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("Error:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

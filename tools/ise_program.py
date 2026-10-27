"""Program a selected LX50 JTAG bitstream using the installed ISE VM.

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
BIT = ROOT / "artifacts/dmd-20261027-d202/appsfpga_repaired_jtag.bit"
EXPECTED_SHA256 = "f88f5a2c105ba33f6bb58b18e802095f4ccd340795d7a084d066c3a0981ce268"
STAGED_BIT_NAME = "selected_jtag.bit"
VM = "ISE_14.7_VIRTUAL_MACHINE"
VBOX = Path(os.environ.get("PROGRAMFILES", "C:/Program Files")) / "Oracle/VirtualBox/VBoxManage.exe"


def startup_clock(path):
    report = path.parent / "reports" / (path.stem + ".bgn")
    if report.is_file():
        setting = re.search(r"\|\s*StartupClk\s*\|\s*(\w+)", report.read_text(errors="replace"))
        if setting:
            return setting.group(1)
    return "unknown"


def recorded_hash(path):
    if path == BIT.resolve():
        return EXPECTED_SHA256
    manifest = path.parent / "artifact_hashes.json"
    if manifest.is_file():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise RuntimeError("artifact_hashes.json must contain a filename-to-hash object")
        return data.get(path.name)
    return None


def list_bitstreams(selected=BIT, root=ROOT):
    selected = selected.resolve()
    paths = {p.resolve() for p in (root / "artifacts").glob("*/*.bit")}
    paths.update(p.resolve() for p in (root / "APPSFPGA_MEM").glob("*.bit"))
    if selected.is_file() and selected.suffix.lower() == ".bit":
        paths.add(selected)
    rows = []
    for path in sorted(paths, key=lambda p: (p != selected, str(p).lower())):
        try:
            digest = recorded_hash(path)
            reference = "recorded" if isinstance(digest, str) and re.fullmatch(r"[0-9a-fA-F]{64}", digest) else "missing"
            clock = startup_clock(path)
        except (OSError, ValueError, RuntimeError):
            reference, clock = "unreadable", "unknown"
        rows.append({"path": path, "selected": path == selected,
                     "startup_clock": clock, "hash_reference": reference})
    return rows


def print_bitstreams(selected):
    rows = list_bitstreams(selected)
    print(f"Bitstreams ({len(rows)}); repository: {ROOT}")
    print("  Clock is from BitGen reports; hash-reference lists availability, not verification.")
    for row in rows:
        path = row["path"]
        display = path.relative_to(ROOT).as_posix() if ROOT in path.parents else str(path)
        marker = "*" if row["selected"] else " "
        print(f"{marker} {display} | clock={row['startup_clock']} | hash-reference={row['hash_reference']}")
    print("* selected; choose a file with --bitstream PATH\n")


def select_bitstream(path, expected_sha256=None):
    path = path.resolve()
    if path.suffix.lower() != ".bit":
        raise RuntimeError("Select a JTAG .bit file, not a .bin or PROM image.")
    raw = path.read_bytes()
    # Xilinx BIT header: preamble, 0x0001 marker, fields a/b/c/d, payload e.
    offset = 0

    def take(count):
        nonlocal offset
        if offset + count > len(raw):
            raise RuntimeError("Truncated BIT header or payload")
        value = raw[offset:offset + count]
        offset += count
        return value

    take(int.from_bytes(take(2), "big"))
    if take(2) != b"\x00\x01":
        raise RuntimeError("Invalid Xilinx BIT header")
    fields = {}
    for tag in b"abcde":
        if take(1) != bytes([tag]):
            raise RuntimeError("Invalid Xilinx BIT header field order")
        size = int.from_bytes(take(4 if tag == ord("e") else 2), "big")
        fields[chr(tag)] = take(size)
    if offset != len(raw) or not fields["e"]:
        raise RuntimeError("Invalid BIT payload length")
    part = fields["b"].rstrip(b"\0").decode("ascii")
    if part.lower() not in ("5vlx50ff1153", "xc5vlx50ff1153"):
        raise RuntimeError(f"Wrong FPGA target {part}; expected LX50 FF1153.")
    if expected_sha256 is None:
        expected_sha256 = recorded_hash(path)
    if not isinstance(expected_sha256, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha256):
        raise RuntimeError("No valid recorded SHA-256. Keep artifact_hashes.json beside the BIT, "
                           "or supply its expected hash with --sha256.")
    sha256 = hashlib.sha256(raw).hexdigest()
    if sha256 != expected_sha256.lower():
        raise RuntimeError("Selected bitstream hash mismatch; no programming attempted.")
    if startup_clock(path).lower() not in ("unknown", "jtagclk"):
        raise RuntimeError("BitGen report specifies a non-JTAG startup clock; select the JTAG variant.")
    return path, sha256, part


def vbox(*args, timeout=30):
    try:
        result = subprocess.run([str(VBOX), *args], capture_output=True, text=True,
                                errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError("VirtualBox command timed out; inspect the run logs before retrying.") from None
    if result.returncode:
        # Do not include the argv: guestcontrol contains the VM login password.
        raise RuntimeError((result.stderr or result.stdout).strip() or
                           f"VirtualBox command failed (exit code {result.returncode})")
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


def impact_failure(folder, name, error):
    log_path = folder / (name + ".log")
    if not log_path.is_file():
        return RuntimeError(f"iMPACT {name} did not produce a log: {error}. Run folder: {folder}")
    log = log_path.read_text(errors="replace")
    if "loopback test failed" in log.lower():
        detail = ("Xilinx USB cable communication/loopback test failed. "
                  "VM attachment metadata does not confirm working cable communication. "
                  "Reconnect the PC-side Xilinx JTAG USB cable before retrying with the board powered on. "
                  "The D4100 pattern USB is a separate cable.")
    elif "a problem may exist in the hardware configuration" in log.lower():
        detail = ("JTAG scan reported a hardware configuration error. "
                  "This log does not establish the cause or the FPGA power state. "
                  "Check the FPGA supplies and JTAG target reference voltage for the actual board revision, "
                  "and that the board-side H1 JTAG connector is seated in the correct orientation. "
                  "Power off the board before changing its header connections.")
        if "Cable connection established." in log:
            detail = "The Xilinx USB cable connected successfully. " + detail
    else:
        lines = [line.strip() for line in log.splitlines()
                 if re.search(r"error|failed|fatal", line, re.I)]
        detail = "\n".join((lines or log.splitlines())[-12:]) or str(error)
    return RuntimeError(f"iMPACT {name} failed: {detail}\nLog: {log_path}")


def run_impact(folder, name, commands, sha256=EXPECTED_SHA256):
    (folder / (name + ".cmd")).write_bytes((commands + "\n").encode("ascii"))
    guest_folder = "/home/ise/C_DRIVE/" + folder.as_posix()[3:]
    script = ("#!/bin/bash\nset -eo pipefail\n"
              "source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n"
              "cd " + shlex.quote(guest_folder) + "\n"
              f"echo '{sha256}  {STAGED_BIT_NAME}' | sha256sum -c - >/dev/null\n"
              f"impact -batch {name}.cmd > {name}.log 2>&1\n")
    (folder / (name + ".sh")).write_bytes(script.encode("utf-8"))
    try:
        vbox("guestcontrol", VM, "run", "--exe", "/bin/bash", "--username", "ise",
             "--password", os.environ.get("ISE_VM_PASSWORD", "xilinx"),
             "--timeout", "300000", "--wait-stdout", "--wait-stderr", "--",
             guest_folder + "/" + name + ".sh", timeout=330)
    except RuntimeError as exc:
        raise impact_failure(folder, name, exc) from None
    # iMPACT can emit ERROR, then return zero after saveCdf/quit. Its exit code
    # alone is not evidence of a successful scan or programming operation.
    log_path = folder / (name + ".log")
    if log_path.is_file() and re.search(r"^\s*(?:ERROR|FATAL)(?::|\s)",
                                       log_path.read_text(errors="replace"), re.M | re.I):
        raise impact_failure(folder, name, RuntimeError("iMPACT reported an error"))


def program(info, bit=BIT, sha256=EXPECTED_SHA256):
    folder = Path(tempfile.mkdtemp(prefix="dmd-jtag-"))
    if folder.drive.upper() != "C:":
        raise RuntimeError("The installed VM shares C:. Set Windows TEMP to a folder on C:.")
    print("Run logs:", folder, flush=True)
    shutil.copyfile(bit, folder / STAGED_BIT_NAME)
    if hashlib.sha256((folder / STAGED_BIT_NAME).read_bytes()).hexdigest() != sha256:
        raise RuntimeError("Copied bitstream hash mismatch")
    record = {"bitstream": str(bit), "bitstream_sha256": sha256, "stage": "prepared",
              "program_verified": False, "vm": VM, "target_position": 1}

    def save():
        (folder / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")

    save()
    try:
        record["stage"] = "identifying"
        save()
        attach_cable(info)
        print("Identifying JTAG chain...", flush=True)
        run_impact(folder, "identify", "setMode -bs\nsetCable -p auto\nIdentify\nsaveCdf -file chain.cdf\nquit", sha256)
        record["chain"] = require_lx50_chain((folder / "chain.cdf").read_text())
        record["stage"] = "programming"
        save()
        print("Programming LX50 position 1...", flush=True)
        run_impact(folder, "program", "setMode -bs\nsetCable -p auto\nIdentify\n"
                   "assignFile -p 1 -file " + STAGED_BIT_NAME + "\nProgram -p 1\nReadStatusRegister -p 1\nquit", sha256)
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
    action.add_argument("--check", action="store_true", help="List bitstreams, check selected file and VM metadata (default)")
    action.add_argument("--program", action="store_true", help="Actually program the powered LX50 via JTAG")
    parser.add_argument("--bitstream", type=Path, default=BIT,
                        help="JTAG BIT path; default: the timing-checked 2026-10-27 D202 candidate")
    parser.add_argument("--sha256", help="Expected file hash when no adjacent artifact_hashes.json is available")
    args = parser.parse_args(argv)
    try:
        if not args.program:
            print_bitstreams(args.bitstream)
        if os.name != "nt":
            raise RuntimeError("Run this helper in Windows PowerShell with the existing Python installation.")
        bit, sha256, part = select_bitstream(args.bitstream, args.sha256)
        info = metadata(vbox("showvminfo", VM, "--machinereadable"))
        print("VM state:", info.get("VMState"), "session:", info.get("SessionName"))
        print("Xilinx cable attached to VM (metadata only):", cable_attached(info))
        print("Bitstream:", bit)
        print("Device:", part)
        print("SHA256:", sha256)
        if not args.program:
            print("Check only: no USB/JTAG device calls and no VM changes.")
            return 0
        if info.get("VMState") != '"running"':
            raise RuntimeError("ISE VM must already be running. No VM/security settings were changed.")
        if not any(key.startswith("SharedFolderName") and value == '"C_DRIVE"' and
                   info.get(key.replace("Name", "Path"), "").strip('"').replace("\\\\", "\\").lower()
                   == "c:\\" for key, value in info.items()):
            raise RuntimeError("The ISE VM needs its existing C_DRIVE shared folder.")
        program(info, bit, sha256)
        return 0
    except (OSError, RuntimeError, ValueError, KeyError) as exc:
        print("Error:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Monitor LX50/LX30 temperature via the existing headless ISE VM and JTAG.

python tools/ise_temperature.py          # console + CSV; Ctrl+C to stop
python tools/ise_temperature.py --once   # one acquisition
python tools/ise_temperature.py --check  # VM/ISE libraries only; no JTAG
Standard library only. Does not program an FPGA or write System Monitor registers.
"""
import argparse
import csv
from datetime import datetime
import math
import os
from pathlib import Path
import re
import shlex
import time

import ise_program as ise

ROOT = Path(__file__).resolve().parents[1]
TCL = Path(__file__).with_suffix(".tcl")
FIELDS = ("timestamp", "elapsed_s", "device", "jtag_index", "idcode", "status",
          "temperature_c", "vccint_v", "vccaux_v", "raw_temperature",
          "raw_vccint", "raw_vccaux", "detail")


def raw_word(value):
    if not re.fullmatch(r"(?:0[xX])?[0-9a-fA-F]{1,4}", value):
        raise ValueError("Malformed 16-bit System Monitor value")
    return int(value, 16)


def parse_readings(output):
    """Reject incomplete runs and preserve raw values even for invalid sensors."""
    if "DMD_SYSMON_DONE" not in output.splitlines():
        raise RuntimeError("ISE did not complete the sensor read. See the acquisition log.")
    rows = []
    seen = set()
    for line in output.splitlines():
        if not line.startswith("DMD_SYSMON\t"):
            continue
        parts = line.split("\t")
        if len(parts) != 9:
            raise RuntimeError("Malformed ISE sensor response")
        _, index, device, idcode, status, temp, core, aux, detail = parts
        if device not in ("xc5vlx50", "xc5vlx30") or not index.isdigit() or index in seen:
            raise RuntimeError("Unexpected or duplicate JTAG device in sensor response")
        seen.add(index)
        row = dict.fromkeys(FIELDS, "")
        row.update(device=device, jtag_index=index, idcode=idcode, status=status,
                   raw_temperature=temp, raw_vccint=core, raw_vccaux=aux, detail=detail)
        if status == "OK":
            try:
                codes = [raw_word(value) >> 6 for value in (temp, core, aux)]
            except ValueError as exc:
                raise RuntimeError(str(exc)) from None
            # UG192 pp.17-20: 10-bit ADC code is MSB justified in a 16-bit word.
            # Endpoint values (including historical all-zero/-273 C readings)
            # cannot be accepted as valid telemetry. This is not a safety verdict.
            if any(code in (0, 1023) for code in codes):
                row.update(status="INVALID", detail="ADC zero/full-scale value; check sensor configuration and analog supply/reference wiring")
            else:
                row.update(status="READ", temperature_c=f"{codes[0] * 503.975 / 1024 - 273.15:.2f}",
                           vccint_v=f"{codes[1] * 3.0 / 1024:.3f}",
                           vccaux_v=f"{codes[2] * 3.0 / 1024:.3f}")
        elif status != "ERROR":
            raise RuntimeError("Unknown ISE sensor status")
        rows.append(row)
    if not rows:
        raise RuntimeError("No FPGA sensor records returned")
    return rows


def guest_path(path):
    path = path.resolve()
    if path.drive.upper() != "C:":
        raise RuntimeError("Use a path on C: (the VM's existing C_DRIVE share).")
    return "/home/ise/C_DRIVE/" + path.as_posix()[3:]


def check_vm():
    if os.name != "nt":
        raise RuntimeError("Run this helper in Windows PowerShell with the existing Python installation.")
    info = ise.metadata(ise.vbox("showvminfo", ise.VM, "--machinereadable", timeout=15))
    print("VM:", info.get("VMState", "unknown"), flush=True)
    if info.get("VMState") != '"running"':
        raise RuntimeError('Start the ISE VM headless first: VBoxManage startvm "' + ise.VM + '" --type headless')
    shared = any(key.startswith("SharedFolderName") and value == '"C_DRIVE"' and
                 info.get(key.replace("Name", "Path"), "").strip('"').replace("\\\\", "\\").lower() == "c:\\"
                 for key, value in info.items())
    if not shared:
        raise RuntimeError("The VM needs its existing C_DRIVE shared folder mapped to C:\\.")
    return info


def write_launcher(folder, argument):
    # Shell arguments are quoted for Bash; neither Windows nor Tcl evaluates a
    # user-supplied path as code. The timeout also bounds a worker after Ctrl+C.
    text = ("#!/bin/bash\nset -eo pipefail\n"
            "source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n"
            "exec timeout -k 2s 25s xtclsh " + shlex.quote(guest_path(TCL)) + " " +
            shlex.quote(argument) + "\n")
    launcher = folder / "acquire.sh"
    launcher.write_bytes(text.encode("utf-8"))
    return guest_path(launcher)


def acquire(launcher, log):
    try:
        output = ise.vbox("guestcontrol", ise.VM, "run", "--exe", "/bin/bash",
                          "--username", "ise", "--password", os.environ.get("ISE_VM_PASSWORD", "xilinx"),
                          "--timeout", "30000", "--wait-stdout", "--wait-stderr", "--",
                          "/bin/bash", launcher, timeout=35)
    except RuntimeError as exc:
        log.write(str(exc) + "\n")
        log.flush()
        raise
    log.write(output + "\n")
    log.flush()
    return output


def positive_interval(value):
    number = float(value)
    if not math.isfinite(number) or number < 1:
        raise argparse.ArgumentTypeError("interval must be a finite number >= 1 second")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Check VM and load ISE Tcl libraries without opening JTAG")
    mode.add_argument("--once", action="store_true", help="Read sensors once and exit")
    parser.add_argument("--interval", type=positive_interval, default=1.0,
                        help="Minimum seconds between acquisitions; ISE/VM startup can make this longer (default 1)")
    parser.add_argument("--port", default="USB21", help="ISE cable port, e.g. USB21 or USB22 (default USB21)")
    parser.add_argument("--output", type=Path, help="New run directory on C:; default runs/thermal/<timestamp>")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"USB[0-9]+", args.port):
        parser.error("--port must be USB followed by digits, e.g. USB21")
    folder = None
    try:
        if not TCL.is_file():
            raise RuntimeError(f"Missing companion script: {TCL}")
        info = check_vm()
        folder = (args.output or ROOT / "runs/thermal" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")).resolve()
        guest_path(folder)
        folder.mkdir(parents=True, exist_ok=False)
        print("Logs:", folder, flush=True)
        launcher = write_launcher(folder, "--check" if args.check else args.port)
        with (folder / "acquisition.log").open("w", encoding="utf-8") as log:
            if args.check:
                if "DMD_SYSMON_READY" not in acquire(launcher, log).splitlines():
                    raise RuntimeError("ISE Tcl library check did not complete; see acquisition.log.")
                print("ISE Tcl libraries loaded. No JTAG access; sensor availability is not yet verified.")
                return 0
            ise.attach_cable(info)
            print("Monitoring LX50/LX30. Ctrl+C to stop. READ means data received, not thermal safety.", flush=True)
            started = time.monotonic()
            invalid_runs = 0
            with (folder / "temperature.csv").open("w", newline="", encoding="utf-8") as csv_file:
                writer = csv.DictWriter(csv_file, fieldnames=FIELDS)
                writer.writeheader()
                csv_file.flush()
                while True:
                    scan_started = time.monotonic()
                    rows = parse_readings(acquire(launcher, log))
                    timestamp = datetime.now().astimezone().isoformat(timespec="milliseconds")
                    elapsed = time.monotonic() - started
                    for row in rows:
                        row.update(timestamp=timestamp, elapsed_s=f"{elapsed:.3f}")
                        writer.writerow(row)
                        if row["status"] == "READ":
                            value = f"{row['temperature_c']} C | VCCINT {row['vccint_v']} V | VCCAUX {row['vccaux_v']} V"
                        else:
                            value = f"{row['status']}: {row['detail']} (raw {row['raw_temperature']}/{row['raw_vccint']}/{row['raw_vccaux']})"
                        print(f"{timestamp}  {row['device']}: {value}", flush=True)
                    missing = {"xc5vlx50", "xc5vlx30"} - {row["device"] for row in rows}
                    for device in sorted(missing):
                        missing_row = dict.fromkeys(FIELDS, "")
                        missing_row.update(timestamp=timestamp, elapsed_s=f"{elapsed:.3f}", device=device,
                                           status="MISSING", detail="Device not found in JTAG chain")
                        writer.writerow(missing_row)
                        print(f"{timestamp}  {device}: MISSING from JTAG chain", flush=True)
                    csv_file.flush()
                    complete = not missing and all(row["status"] == "READ" for row in rows)
                    if args.once:
                        return 0 if complete else 2
                    invalid_runs = 0 if any(row["status"] == "READ" for row in rows) else invalid_runs + 1
                    if invalid_runs >= 3:
                        raise RuntimeError("No usable sensor readings in three acquisitions. Check System Monitor configuration and analog supply/reference wiring.")
                    time.sleep(max(0, args.interval - (time.monotonic() - scan_started)))
    except KeyboardInterrupt:
        print("\nMonitoring stopped. An in-flight ISE read has a 25-second timeout plus a 2-second kill grace period.")
        return 130
    except (OSError, RuntimeError, ValueError) as exc:
        print("Error:", exc)
        if folder is not None:
            print("Logs:", folder)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Reproducible ISE build using only Python's standard library and installed ISE.

Windows: python tools/ise_build.py --stage synth --build C:/Temp/dmd-build
Uses the installed ISE VirtualBox appliance and its C_DRIVE shared folder.
Linux: source ISE_DS/settings64.sh, then use the same command with a Linux path.
Existing .bit files are never overwritten. No hardware programming is performed.
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


def prepare(build):
    root = Path(__file__).resolve().parents[1] / "APPSFPGA_MEM"
    if build == root or root in build.parents:
        raise ValueError("Use a separate build directory outside APPSFPGA_MEM")
    build.mkdir(parents=True, exist_ok=True)
    files = {"appsfpga.prj", "appsfpga.xst", "appsfpga.ut"}
    for line in (root / "appsfpga.prj").read_text().splitlines():
        match = re.search(r'"([^"]+)"', line)
        if match:
            files.add(match[1])
    for directory in (root / "src/rtl", root / "ipcore_dir"):
        files.update(p.relative_to(root).as_posix() for p in directory.glob("*.ngc"))
    files.update(p.relative_to(root).as_posix() for p in (root / "src/rtl").glob("*.ucf"))
    for name in sorted(files):
        source = root / name
        dest = build / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
    hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
              for name in sorted(files)}
    (build / "source_hashes.json").write_text(json.dumps(hashes, indent=2))
    (build / "xst/projnav.tmp").mkdir(parents=True, exist_ok=True)
    constraints = "\n".join((root / "src/rtl" / n).read_text()
                            for n in ("merge.ucf", "ddr2_sdram.ucf", "timing.ucf"))
    (build / "combined.ucf").write_text(constraints)
    (build / "appsfpga_jtag.ut").write_text(
        (root / "appsfpga.ut").read_text().replace("StartUpClk:CClk", "StartUpClk:JtagClk"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=("prepare", "synth", "implement"), default="synth")
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--vm", default="ISE_14.7_VIRTUAL_MACHINE")
    args = parser.parse_args()
    build = args.build.resolve()
    if any((build / name).exists() for name in
           ("appsfpga_repaired.bit", "appsfpga_repaired_jtag.bit")):
        parser.error("This folder already contains a generated bitstream. Use a fresh --build directory to preserve its source manifest and reports.")
    prepare(build)
    if args.stage == "prepare":
        print(build)
        return
    windows = os.name == "nt"
    if windows:
        if build.drive.upper() != "C:":
            raise ValueError("The appliance shares C: as /home/ise/C_DRIVE")
        guest_build = "/home/ise/C_DRIVE/" + build.as_posix()[3:]
    else:
        guest_build = str(build)
    commands = ["xst -ifn appsfpga.xst -ofn appsfpga.syr"]
    if args.stage == "implement":
        commands += [
            "ngdbuild -p xc5vlx50-1-ff1153 -sd src/rtl -sd ipcore_dir -uc combined.ucf appsfpga.ngc appsfpga.ngd",
            "map -w -p xc5vlx50-1-ff1153 -ol high -o appsfpga_map.ncd appsfpga.ngd appsfpga.pcf && ! grep -q 'are not locked' appsfpga_map.mrp",
            # Still run TRCE for diagnostics if PAR returns a timing failure.
            "par -w -ol high appsfpga_map.ncd appsfpga.ncd appsfpga.pcf || test -s appsfpga.ncd",
            # One extra-effort routing pass for small residual setup failures.
            # Keep the original reports; never weaken clock or hold constraints.
            # TRCE can return zero even when the report contains timing errors.
            "trce -v 20 -u 20 -o appsfpga.twr appsfpga.ncd appsfpga.pcf\n"
            "if ! grep -q 'All constraints were met' appsfpga.twr; then\n"
            "cp appsfpga.par appsfpga_initial.par\n"
            "cp appsfpga.twr appsfpga_initial.twr\n"
            "par -w -k -ol high -xe c appsfpga.ncd appsfpga_retry.ncd appsfpga.pcf > retry_par.log 2>&1 || test -s appsfpga_retry.ncd\n"
            "trce -v 20 -u 20 -o appsfpga.twr appsfpga_retry.ncd appsfpga.pcf > retry_trace.log 2>&1\n"
            "cp appsfpga_retry.ncd appsfpga.ncd\n"
            "cp appsfpga_retry.par appsfpga.par\nfi",
            # Never publish a bitstream with known timing failures.
            "grep -q 'All constraints were met' appsfpga.twr",
            # The .ut files already contain -w; BitGen rejects duplicate flags.
            "bitgen -f appsfpga.ut appsfpga.ncd appsfpga_repaired.bit appsfpga.pcf",
            "bitgen -f appsfpga_jtag.ut appsfpga.ncd appsfpga_repaired_jtag.bit appsfpga.pcf",
        ]
    script = "#!/bin/bash\nset -euo pipefail\n"
    if windows:
        # settings64.sh references unset variables; source before enabling -u.
        script = "#!/bin/bash\nset -eo pipefail\nsource /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n"
        # The appliance's old Guest Additions can busy-poll while waiting for
        # guestcontrol output. Lower only this invocation's helper priority;
        # the already-started shell and ISE child processes retain normal priority.
        script += 'if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi\n'
    script += "cd " + shlex.quote(guest_build) + "\n"
    if windows:
        # VirtualBox shared folders are very slow for XST's many small files.
        # Compile on the guest's local disk, copy reviewable outputs back on exit.
        script += "destination=" + shlex.quote(guest_build) + "\n"
        script += 'work=$(mktemp -d /tmp/hs_dmd_build.XXXXXX)\n'
        script += 'cp -r src ipcore_dir appsfpga.prj appsfpga.xst appsfpga.ut appsfpga_jtag.ut combined.ucf "$work/"\n'
        script += 'cd "$work"\nmkdir -p xst/projnav.tmp\n'
        script += "trap 'cp -f *.syr *.ngc *.ngd *.ncd *.pcf *.mrp *.par *.twr *.bit *.bin *.bgn *.bld *.map *.log \"$destination/\" 2>/dev/null || true' EXIT\n"
    for i, command in enumerate(commands):
        script += "{ " + command + "; } > stage_%02d.log 2>&1\n" % i
        script += "tail -n 12 stage_%02d.log\n" % i
    (build / "run_build.sh").write_bytes(script.encode("utf-8"))
    if windows:
        vbox = Path(os.environ.get("PROGRAMFILES", "C:/Program Files")) / "Oracle/VirtualBox/VBoxManage.exe"
        cmd = [str(vbox), "guestcontrol", args.vm, "run", "--exe", "/bin/bash",
               "--username", "ise", "--password", "xilinx", "--timeout", "7200000",
               "--wait-stdout", "--wait-stderr", "--", guest_build + "/run_build.sh"]
    else:
        cmd = ["bash", str(build / "run_build.sh")]
    subprocess.run(cmd, check=True)
    if args.stage == "implement":
        outputs = ["appsfpga_repaired.bit", "appsfpga_repaired.bin",
                   "appsfpga_repaired_jtag.bit", "appsfpga_repaired_jtag.bin",
                   "appsfpga.par", "appsfpga.twr", "source_hashes.json"]
        hashes = {name: hashlib.sha256((build / name).read_bytes()).hexdigest()
                  for name in outputs}
        (build / "artifact_hashes.json").write_text(json.dumps(hashes, indent=2))
        print("Timing-checked bitstreams and artifact_hashes.json:", build)


if __name__ == "__main__":
    main()

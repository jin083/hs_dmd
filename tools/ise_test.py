"""Run self-checking ISim regressions with installed ISE, without downloads.

python tools/ise_test.py --build C:/Temp/dmd-tests
The MIG user interface is modeled; real supplied Xilinx FIFO simulation models
are used. These tests do not validate the electrical DDR2 or DMD interfaces.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess

TESTS = {
    "memory_playback_tb": [
        "src/rtl/MEM_IO_Verilog.v", "src/rtl/ddr_pattern_engine.v",
        "src/rtl/dmd_frame_streamer.v", "src/rtl/memory_playback.v", "src/rtl/pattern_store.v",
        "src/sim/mig_user_model.v", "src/sim/memory_playback_tb.v",
        "src/sim/harness/playback_harness.vh",
        "ipcore_dir/read_fifo.vhd",
    ],
    "usb_memory_tb": [
        "src/rtl/USB_IO.vhd", "src/rtl/usb_dcm.vhd", "src/rtl/FIFO_RCV2.vhd",
        "src/rtl/fifo_register.vhd", "ipcore_dir/fifo.vhd", "src/sim/usb_memory_tb.vhd",
    ],
}
TESTS["pattern_store_tb"] = [p.replace("memory_playback_tb.v", "pattern_store_tb.v") for p in TESTS["memory_playback_tb"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--vm", default="ISE_14.7_VIRTUAL_MACHINE")
    parser.add_argument("--ise", default="/opt/Xilinx/14.7/ISE_DS/ISE")
    parser.add_argument("--test", choices=tuple(TESTS), action="append")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / "APPSFPGA_MEM"
    build = args.build.resolve()
    if build == root or root in build.parents:
        raise ValueError("Use a separate build directory outside APPSFPGA_MEM")
    build.mkdir(parents=True, exist_ok=True)
    windows = os.name == "nt"
    if windows and build.drive.upper() != "C:":
        raise ValueError("Use the appliance's shared C: drive")
    guest = "/home/ise/C_DRIVE/" + build.as_posix()[3:] if windows else str(build)
    script = "#!/bin/bash\nset -eo pipefail\n"
    if windows:
        script += "source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n"
        # Avoid CPU contention with the appliance's busy-polling guestcontrol helper.
        script += 'if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi\n'
    script += "destination=" + shlex.quote(guest) + "\n"
    script += 'work=$(mktemp -d /tmp/hs_dmd_test.XXXXXX)\n'
    manifest = {}
    for test, files in TESTS.items():
        if args.test and test not in args.test:
            continue
        folder = build / test
        folder.mkdir(exist_ok=True)
        sources = ""
        dependencies = ["fifo_generator_v9_3"]
        if test == "usb_memory_tb":
            dependencies += ["iputils_std_logic_arith", "iputils_std_logic_unsigned",
                             "iputils_conv", "iputils_misc", "fifo_generator_v4_3"]
        for model in dependencies:
            sources += 'vhdl XilinxCoreLib "%s/vhdl/src/XilinxCoreLib/%s.vhd"\n' % (args.ise, model)
        for name in files:
            source = root / name
            shutil.copy2(source, folder / source.name)
            manifest[name] = hashlib.sha256(source.read_bytes()).hexdigest()
            if source.suffix == ".vh":
                continue
            language = "vhdl" if source.suffix in (".vhd", ".vhdl") else "verilog"
            sources += '%s work "%s"\n' % (language, source.name)
        (folder / "test.prj").write_text(sources)
        # PLL behavioral models can keep scheduling events after the test ends.
        # Bound virtual runtime; PASS is mandatory even if ISim exits with code 0.
        duration = "100 us" if test == "usb_memory_tb" else "32 ms"
        (folder / "run.tcl").write_bytes(("run " + duration + "\nquit\n").encode())
        script += 'cp -r "$destination/%s" "$work/"\ncd "$work/%s"\n' % (test, test)
        script += "trap 'cp -f compile.log simulation.log \"$destination/%s/\" 2>/dev/null || true' EXIT\n" % test
        script += 'fuse -prj test.prj -L XilinxCoreLib -L unisim -o test_sim work.%s > compile.log 2>&1\n' % test
        script += './test_sim -tclbatch run.tcl > simulation.log 2>&1\n'
        script += 'cp compile.log simulation.log "$destination/%s/"\n' % test
        script += "grep -E 'PASS:|FAIL:' simulation.log\n"
        script += "grep -q 'PASS: %s' simulation.log\n" % test
        script += "! grep -q 'FAIL:' simulation.log\n"
    script += "trap - EXIT\n"
    (build / "run_tests.sh").write_bytes(script.encode())
    (build / "source_hashes.json").write_text(json.dumps(manifest, indent=2))
    if windows:
        vbox = Path(os.environ.get("PROGRAMFILES", "C:/Program Files")) / "Oracle/VirtualBox/VBoxManage.exe"
        command = [str(vbox), "guestcontrol", args.vm, "run", "--exe", "/bin/bash",
                   "--username", "ise", "--password", "xilinx", "--timeout", "1800000",
                   "--wait-stdout", "--wait-stderr", "--", guest + "/run_tests.sh"]
    else:
        command = ["bash", str(build / "run_tests.sh")]
    result = subprocess.run(command, check=False)
    if result.returncode:
        raise SystemExit(f"ISE failed (exit {result.returncode}); inspect logs in {build}")
    print("All self-checking ISim regressions passed.")


if __name__ == "__main__":
    main()

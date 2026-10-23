#!/bin/bash
set -eo pipefail
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
cd /tmp/hs_dmd_build.MZTFlp
destination=/home/ise/C_DRIVE/Temp/dmd-release-cdc-20261023
trap 'cp -f *.bit *.bin *.bgn stage_06.log stage_07.log "$destination/" 2>/dev/null || true' EXIT
grep -q 'All constraints were met' appsfpga.twr
bitgen -f appsfpga.ut appsfpga.ncd appsfpga_repaired.bit appsfpga.pcf > stage_06.log 2>&1
tail -n 18 stage_06.log
bitgen -f appsfpga_jtag.ut appsfpga.ncd appsfpga_repaired_jtag.bit appsfpga.pcf > stage_07.log 2>&1
tail -n 18 stage_07.log

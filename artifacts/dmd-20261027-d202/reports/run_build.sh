#!/bin/bash
set -eo pipefail
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
cd /home/ise/C_DRIVE/Temp/dmd-d202-build-08
destination=/home/ise/C_DRIVE/Temp/dmd-d202-build-08
work=$(mktemp -d /tmp/hs_dmd_build.XXXXXX)
cp -r src ipcore_dir appsfpga.prj appsfpga.xst appsfpga.ut appsfpga_jtag.ut combined.ucf "$work/"
cd "$work"
mkdir -p xst/projnav.tmp
trap 'cp -f *.syr *.ngc *.ngd *.ncd *.pcf *.mrp *.par *.twr *.bit *.bin *.bgn *.bld *.map *.log "$destination/" 2>/dev/null || true' EXIT
{ xst -ifn appsfpga.xst -ofn appsfpga.syr; } > stage_00.log 2>&1
tail -n 12 stage_00.log
{ ngdbuild -p xc5vlx50-1-ff1153 -sd src/rtl -sd ipcore_dir -uc combined.ucf appsfpga.ngc appsfpga.ngd; } > stage_01.log 2>&1
tail -n 12 stage_01.log
{ map -w -p xc5vlx50-1-ff1153 -ol high -o appsfpga_map.ncd appsfpga.ngd appsfpga.pcf && ! grep -q 'are not locked' appsfpga_map.mrp; } > stage_02.log 2>&1
tail -n 12 stage_02.log
{ par -w -ol high appsfpga_map.ncd appsfpga.ncd appsfpga.pcf || test -s appsfpga.ncd; } > stage_03.log 2>&1
tail -n 12 stage_03.log
{ trce -v 20 -u 20 -o appsfpga.twr appsfpga.ncd appsfpga.pcf
if ! grep -q 'All constraints were met' appsfpga.twr; then
cp appsfpga.par appsfpga_initial.par
cp appsfpga.twr appsfpga_initial.twr
par -w -k -ol high -xe c appsfpga.ncd appsfpga_retry.ncd appsfpga.pcf > retry_par.log 2>&1 || test -s appsfpga_retry.ncd
trce -v 20 -u 20 -o appsfpga.twr appsfpga_retry.ncd appsfpga.pcf > retry_trace.log 2>&1
cp appsfpga_retry.ncd appsfpga.ncd
cp appsfpga_retry.par appsfpga.par
fi; } > stage_04.log 2>&1
tail -n 12 stage_04.log
{ grep -q 'All constraints were met' appsfpga.twr; } > stage_05.log 2>&1
tail -n 12 stage_05.log
{ bitgen -f appsfpga.ut appsfpga.ncd appsfpga_repaired.bit appsfpga.pcf; } > stage_06.log 2>&1
tail -n 12 stage_06.log
{ bitgen -f appsfpga_jtag.ut appsfpga.ncd appsfpga_repaired_jtag.bit appsfpga.pcf; } > stage_07.log 2>&1
tail -n 12 stage_07.log

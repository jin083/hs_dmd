#!/bin/bash
set -eo pipefail
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
destination=/home/ise/C_DRIVE/Temp/dmd-d202-tests-11
work=$(mktemp -d /tmp/hs_dmd_test.XXXXXX)
cp -r "$destination/memory_playback_tb" "$work/"
cd "$work/memory_playback_tb"
trap 'cp -f compile.log simulation.log "$destination/memory_playback_tb/" 2>/dev/null || true' EXIT
fuse -prj test.prj -L XilinxCoreLib -L unisim -o test_sim work.memory_playback_tb > compile.log 2>&1
./test_sim -tclbatch run.tcl > simulation.log 2>&1
cp compile.log simulation.log "$destination/memory_playback_tb/"
grep -E 'PASS:|FAIL:' simulation.log
grep -q 'PASS: memory_playback_tb' simulation.log
! grep -q 'FAIL:' simulation.log
cp -r "$destination/usb_memory_tb" "$work/"
cd "$work/usb_memory_tb"
trap 'cp -f compile.log simulation.log "$destination/usb_memory_tb/" 2>/dev/null || true' EXIT
fuse -prj test.prj -L XilinxCoreLib -L unisim -o test_sim work.usb_memory_tb > compile.log 2>&1
./test_sim -tclbatch run.tcl > simulation.log 2>&1
cp compile.log simulation.log "$destination/usb_memory_tb/"
grep -E 'PASS:|FAIL:' simulation.log
grep -q 'PASS: usb_memory_tb' simulation.log
! grep -q 'FAIL:' simulation.log
cp -r "$destination/pattern_store_tb" "$work/"
cd "$work/pattern_store_tb"
trap 'cp -f compile.log simulation.log "$destination/pattern_store_tb/" 2>/dev/null || true' EXIT
fuse -prj test.prj -L XilinxCoreLib -L unisim -o test_sim work.pattern_store_tb > compile.log 2>&1
./test_sim -tclbatch run.tcl > simulation.log 2>&1
cp compile.log simulation.log "$destination/pattern_store_tb/"
grep -E 'PASS:|FAIL:' simulation.log
grep -q 'PASS: pattern_store_tb' simulation.log
! grep -q 'FAIL:' simulation.log
trap - EXIT

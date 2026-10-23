#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
cd /home/ise/C_DRIVE/Temp/dmd-program-20261023
impact -batch program.cmd > impact_program.log 2>&1
result=$?
tail -n 110 impact_program.log
exit "$result"

#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z
work=$(mktemp -d /tmp/dmd_flash_program.XXXXXX)
echo "$work" > program_guest_dir.txt
cp d202_spi_boot.mcs d202_spi_boot.cfi program_flash.cmd "$work/"
cd "$work"
impact -batch program_flash.cmd > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z/program_flash.log 2>&1
rc=$?
if test -f programmed_chain.cdf; then cp programmed_chain.cdf /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z/; fi
echo $rc > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z/program_flash.exitcode
exit $rc

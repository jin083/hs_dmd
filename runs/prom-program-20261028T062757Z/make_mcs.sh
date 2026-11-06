#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
work=$(mktemp -d /tmp/dmd_prom_image.XXXXXX)
cp d202_spi_boot.bit "$work/"
cd "$work"
promgen -w -spi -p mcs -s 4096 -u 0 d202_spi_boot.bit -o d202_spi_boot > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/promgen.log 2>&1
rc=$?
cp d202_spi_boot.mcs d202_spi_boot.prm /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/
echo $rc > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/promgen.exitcode
exit $rc

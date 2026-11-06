#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T050157Z || exit 2
command -v pdftotext > pdf-tool.txt
timeout 60s impact -batch spi_help2.cmd > spi_help2.log 2>&1
rc=$?
echo "$rc" > spi_help2.exitcode
exit "$rc"

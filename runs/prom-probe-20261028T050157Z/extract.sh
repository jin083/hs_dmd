#!/bin/bash
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T050157Z || exit 2
pdftotext -layout reference/DLPLCRC410EVM_RevC_SCH.pdf reference/schematic.txt
pdftotext -layout reference/DLPLCRC410EVM_RevC_ASSY.pdf reference/assembly.txt
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
timeout 30s impact -batch spi_manual.cmd > spi_manual.log 2>&1

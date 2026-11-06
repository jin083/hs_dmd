#!/bin/bash
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T050157Z || exit 2
pdftoppm -f 5 -l 5 -r 85 -png reference/DLPLCRC410EVM_RevC_SCH.pdf reference/schematic-page5
pdftoppm -f 7 -l 7 -r 85 -png reference/DLPLCRC410EVM_RevC_SCH.pdf reference/schematic-page7
find /opt/Xilinx/14.7/ISE_DS/ISE -iname "*spi*" -o -iname "*flash*" > ise_flash_files.txt

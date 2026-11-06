#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
mkdir -p reference
cp /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp/pim_p_configure_spi_bpi_through_fpga.htm reference/
cp /opt/Xilinx/14.7/ISE_DS/ISE/data/spi.acd reference/
cat > command_help.cmd <<'EOF'
help program
help readbackToFile
help readIdcode
help readCFI
help assignFile
help configure
quit
EOF
timeout 30s impact -batch command_help.cmd > command_help.log 2>&1

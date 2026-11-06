import run_step as s
s.guest('offline_tools', '''ls -l /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64/impact /opt/Xilinx/14.7/ISE_DS/settings32.sh
file /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact
ls /opt/Xilinx
ls /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libImpact* /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin64/libImpact*
''',timeout=20)

import run_step as s
s.guest('usb32_libraries', '''find /usr/lib /lib /opt/Xilinx/14.7/ISE_DS/common/lib/lin /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin -maxdepth 3 -iname '*usb*so*' -print
ldd /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseJtag.so
''',timeout=20)

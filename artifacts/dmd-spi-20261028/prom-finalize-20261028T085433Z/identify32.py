import run_step as s
(s.FOLDER/'identify32.cmd').write_text('setMode -bs\nsetCable -p usb21 -baud 1500000\nIdentify\nsaveCdf -file chain32.cdf\nquit\n')
s.guest('identify32', '''source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
command -v linux32
linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch identify32.cmd > identify32.log 2>&1
rc=$?
echo $rc > identify32.exitcode
cat identify32.log
exit $rc''',timeout=60)
if (s.FOLDER/'chain32.cdf').exists():
    s.p.require_lx50_chain((s.FOLDER/'chain32.cdf').read_text())
    print('32BIT_CHAIN_CONFIRMED')

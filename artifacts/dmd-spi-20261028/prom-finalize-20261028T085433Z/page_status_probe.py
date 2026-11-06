import re
import run_step as s
base=(s.FOLDER/'id_clean.svf').read_text().splitlines()
lines=(s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf').read_text().splitlines()
def status(value):
 return f"SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (000000a008006a956a95);\nRUNTEST 144 TCK;\nSDR 80 TDI (00000000000000a00800) SMASK (ffffffffffffffffffff) TDO ({value << 24:020x}) MASK (000000000000ff000000);\n"
write='\n'.join(lines[392945:392951])+'\n'+status(0x40)+'\n'.join(lines[392951:392965])+'\nRUNTEST 150000 TCK;\n'+status(0)
read='\n'.join(lines[515585:515639])
body=(status(0)+write+read).replace('SIR 10 TDI (03c2)','SIR 10 TDI (3c2)').replace('SIR 10 TDI (03c3)','SIR 10 TDI (3c3)')
(s.FOLDER/'page_status_probe.svf').write_bytes(('\n'.join(base[:11])+'\n'+body+'\n'+'\n'.join(base[11:])+'\n').encode())
s.impact('page_status_probe','setMode -bs\naddDevice -p 1 -file page_status_probe.svf\nsetCable -p usb21 -baud 1500000\nplay -cont_on_fail -showalltdo\nquit',timeout=60)

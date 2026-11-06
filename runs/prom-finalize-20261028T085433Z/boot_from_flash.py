"""After complete Flash verification, reconfigure LX50 using JPROGRAM only."""
import hashlib,json,re
from datetime import datetime,timezone
import run_step as s
result=json.loads((s.FOLDER/'padded_program_result.json').read_text())
assert result['flash_program_verified'] is True
expected='ea90d7e62c49b016e2c9f755ebebb6b1d42174383be13dc0cf8c05cbf8f6999c'
assert result['verified_image_sha256']==expected
assert hashlib.sha256((s.FOLDER/'d202_verified_flash_prefix.bin').read_bytes()[:result['image_bytes']]).hexdigest()==expected
base=(s.FOLDER/'id_clean.svf').read_text().splitlines()
# UG191 Table 3-7: JPROGRAM is equivalent to PROGRAM_B; JSTART is only for TCK startup.
# Target LX50 only. The other FPGA remains in BYPASS. No CFG_IN or bitstream transfer.
body='SIR 10 TDI (3cb);\nRUNTEST 150000 TCK;\nSIR 10 TDI (3ff);\nRUNTEST 30000000 TCK;\n'
(s.FOLDER/'boot_from_flash.svf').write_bytes(('\n'.join(base[:11])+'\n'+body+'\n'.join(base[11:])+'\n').encode())
s.impact('boot_from_flash','setMode -bs\naddDevice -p 1 -file boot_from_flash.svf\nsetCable -p usb21 -baud 1500000\nplay\nquit',timeout=120)
log=(s.FOLDER/'boot_from_flash.log').read_text()
assert 'Play svf succeeded.' in log and 'ERROR:' not in log
s.impact('flash_boot_status','setMode -bs\naddDevice -p 1 -part xc5vlx50\naddDevice -p 2 -part xc5vlx30\nsetCable -p usb21 -baud 1500000\nReadStatusRegister -p 1\nquit',timeout=60)
log=(s.FOLDER/'flash_boot_status.log').read_text()
checks={}
for label,value in {'CRC error':0,'Indicates when ID value written does not match chip ID':0,'read back crc error':0,'Value of DONE pin':1,'Internal signal indicates that chip is configured':1,'End of startup signal from Startup block':1}.items():
 matches=re.findall(re.escape(label)+r'\s*:\s*([01])',log)
 assert matches and int(matches[-1])==value,(label,matches)
 checks[label]=value
out={'time_utc':datetime.now(timezone.utc).isoformat(),'flash_reload_successful':True,'method':'LX50 JPROGRAM followed by BYPASS and wait; no configuration bitstream data sent from PC','status_register_checks':checks,'verified_flash_image_sha256':expected,'physical_power_cycle_tested':False,'usb_abi_checked':False,'lx30_programmed':False}
(s.FOLDER/'flash_boot_result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))

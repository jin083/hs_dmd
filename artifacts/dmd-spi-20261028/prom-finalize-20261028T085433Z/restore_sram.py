import hashlib,json,shutil
from datetime import datetime,timezone
import run_step as s
bit,digest,part=s.p.select_bitstream(s.p.BIT)
shutil.copyfile(bit,s.FOLDER/'d202_jtag.bit')
assert hashlib.sha256((s.FOLDER/'d202_jtag.bit').read_bytes()).hexdigest()==digest
s.impact('restore_sram', '''setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
assignFile -p 1 -file d202_jtag.bit
Program -p 1
ReadStatusRegister -p 1
quit''',timeout=180)
checks=s.p.verify_program_log((s.FOLDER/'restore_sram.log').read_text())
result={'time_utc':datetime.now(timezone.utc).isoformat(),'d202_sram_restored':True,'sha256':digest,'status_register_checks':checks,'flash_modified_by_this_step':False}
(s.FOLDER/'sram_result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2),flush=True)

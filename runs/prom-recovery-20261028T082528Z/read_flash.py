import json,shutil
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'
out=art/s.FOLDER.name
out.mkdir(exist_ok=True)
for name in ('identify.cmd','identify.log','chain.cdf','restore_sram.cmd','restore_sram.log','sram_result.json'):
    shutil.copyfile(s.FOLDER/name,out/name)
latest=json.loads((art/'latest_result.json').read_text())
latest.update(updated_utc=datetime.now(timezone.utc).isoformat(),status='d202_sram_recovered_reading_flash',d202_sram_restored=True,host_jtag_usb_detected=True,guest_jtag_usb_detected=True,recovery_blocker=None,recovery_run=s.FOLDER.name,all_impact_operations_stopped=False)
(art/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')
s.impact('postwrite_read', '''setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
readbackToFile -p 1 -spi S25FL032P -file postwrite_read.mcs
quit''',timeout=1800)

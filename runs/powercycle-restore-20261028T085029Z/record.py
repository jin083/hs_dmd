import hashlib,json,re,shutil
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'; out=art/s.FOLDER.name; out.mkdir(exist_ok=True)
for name in ('identify.cmd','identify.log','chain.cdf','restore_sram.cmd','restore_sram.log','sram_result.json'):
    shutil.copyfile(s.FOLDER/name,out/name)
pre=(s.FOLDER/'identify.log').read_text()
prechecks={}
for label in ('Value of DONE pin','Internal signal indicates that chip is configured','End of startup signal from Startup block'):
    prechecks[label]=int(re.findall(r'^\s*'+re.escape(label)+r'\s*:\s*([01])\b',pre,re.M)[-1])
usbfiles=list((s.FOLDER/'usb_status').glob('*/result.json'))
assert len(usbfiles)==1
shutil.copyfile(usbfiles[0],out/'usb_status.json')
usb=json.loads(usbfiles[0].read_text(encoding='utf-8'))
recovery=json.loads((s.FOLDER/'sram_result.json').read_text())
record={'time_utc':datetime.now(timezone.utc).isoformat(),'user_reported_power_cycle':True,'before_programming':prechecks,'after_programming':recovery,'usb_status_execution':usb['execution'],'usb_status_error':usb.get('error'),'flash_written':False}
(out/'powercycle_result.json').write_text(json.dumps(record,indent=2)+'\n')
latest=json.loads((art/'latest_result.json').read_text())
latest.update(updated_utc=record['time_utc'],d202_sram_restored_utc=recovery['time_utc'],active_fpga_design='D202',d202_sram_restored=True,latest_powercycle_restore_run=s.FOLDER.name,user_reported_power_cycle_after_flash_write=True,post_powercycle_before_sram_status=prechecks,usb_status_execution=usb['execution'],usb_status_error=usb.get('error'),all_impact_operations_stopped=True)
(art/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')
manifest={p.relative_to(art).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(art.rglob('*')) if p.is_file() and p!=art/'sha256.json'}
(art/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
assert manifest['original_apps_full.bin']=='7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
print(json.dumps(record,indent=2))

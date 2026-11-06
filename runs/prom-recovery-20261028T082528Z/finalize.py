import hashlib,json,shutil
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'; out=art/s.FOLDER.name
for name in ('restore_sram_before_read.log','sram_result_before_read.json','restore_sram.cmd','restore_sram.log','sram_result.json','program32.cmd','program32.log','program32.exitcode'):
    shutil.copyfile(s.FOLDER/name,out/name)
s.guest('final_process_check','pgrep -x impact > final_impact_pids.txt || true\ncat final_impact_pids.txt',timeout=15)
pids=(s.FOLDER/'final_impact_pids.txt').read_text().strip()
assert not pids, 'An iMPACT process remains active'
shutil.copyfile(s.FOLDER/'final_impact_pids.txt',out/'final_impact_pids.txt')
latest=json.loads((art/'latest_result.json').read_text())
latest.update(updated_utc=datetime.now(timezone.utc).isoformat(),status='d202_sram_recovered_flash_blank_awaiting_legacy_tool',active_fpga_design='D202',d202_sram_restored=True,d202_sram_restored_utc=json.loads((s.FOLDER/'sram_result.json').read_text())['time_utc'],flash_boot_integrity='blank_confirmed_full_read',postwrite_read_in_progress=False,postwrite_read_bytes=4194304,postwrite_read_non_ff_bytes=0,postwrite_read_elapsed_seconds=947,postwrite_read_bin_sha256='cd3517473707d59c3d915b52a3e16213cadce80d9ffb2b4371958fb7acb51a08',recovery_program_tool='ISE 14.7 lin 32-bit',recovery_program_entered_flash_write=False,recovery_program_erase=False,recovery_program_failure='32-bit iMPACT cable operation is unsupported on the 64-bit OS; stopped before cable connection',all_impact_operations_stopped=True,recovery_blocker='Legacy iMPACT installation package/runtime needed for the next compatibility trial; current 14.7 lin64 write failed and lin32 cable path is unsupported.',next_tool_candidate='ISE Lab Tools 14.1',original_flash_restored=False)
for dest in (art/'latest_result.json',out/'recovery_result.json'):
    dest.write_text(json.dumps(latest,indent=2)+'\n')
manifest={p.relative_to(art).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(art.rglob('*')) if p.is_file() and p!=art/'sha256.json'}
(art/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
for name,digest in manifest.items():
    assert hashlib.sha256((art/name).read_bytes()).hexdigest()==digest
assert manifest['original_apps_full.mcs']=='17ba24929d9cc51c57ea6595a3bb28d42a7d1601cdb626cac0dba45974ee538b'
assert manifest['original_apps_full.bin']=='7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
print(json.dumps({'final_status':latest['status'],'all_impact_operations_stopped':True,'archived_files_verified':len(manifest),'original_backup_hashes_unchanged':True,'final_sram_checks':json.loads((s.FOLDER/'sram_result.json').read_text())['status_register_checks']},indent=2))

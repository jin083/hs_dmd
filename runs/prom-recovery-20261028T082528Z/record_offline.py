import json,shutil
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'; out=art/s.FOLDER.name
for name in ('offline_svf_comparison.json','offline_svf_default.log','offline_svf_width1_64.log','offline_svf_width1_32.log','offline_help.log'):
    shutil.copyfile(s.FOLDER/name,out/name)
latest=json.loads((art/'latest_result.json').read_text())
latest.update(updated_utc=datetime.now(timezone.utc).isoformat(),active_fpga_design='temporary_spi_access_core',postwrite_read_in_progress=True,recovery_blocker=None)
(art/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')

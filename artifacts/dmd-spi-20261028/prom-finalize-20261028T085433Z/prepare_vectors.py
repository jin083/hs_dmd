from pathlib import Path
import run_step as s
lines=(s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf').read_text().splitlines()
assert "'write enable'" in lines[392945]
assert "'page program'" in lines[392951]
assert "'read '" in lines[515590]
assert 'MASK (' in '\n'.join(lines[515604:515639])
header=lines[:17]
header=[line.replace('1E6 HZ','1500000 HZ') for line in header]
(s.FOLDER/'id_only.svf').write_text('\n'.join(header+['STATE RESET;'])+'\n')
(s.FOLDER/'probe_vectors.svf').write_text('\n'.join(header+lines[392945:392965]+lines[515585:515639]+['STATE RESET;'])+'\n')
(s.FOLDER/'play_id.cmd').write_text('setMode -bsfile\naddDevice -p 1 -file id_only.svf\nsetCable -p usb21 -baud 1500000\nplay\nquit\n')
s.impact('play_id',(s.FOLDER/'play_id.cmd').read_text(),timeout=60)

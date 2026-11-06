from pathlib import Path
import run_step as s
text=(s.FOLDER/'id_only.svf').read_text().replace('STATE RESET;\n','STATE RESET;\nSTATE IDLE;\n')
(s.FOLDER/'id_only.svf').write_text(text)
s.impact('play_id_retry','setMode -bs\naddDevice -p 1 -file id_only.svf\nsetCable -p usb21 -baud 1500000\nplay\nquit',timeout=60)

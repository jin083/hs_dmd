import run_step as s
base=(s.FOLDER/'id_clean.svf').read_text().splitlines()
body="""SIR 10 TDI (3c2);
RUNTEST 10 TCK;
SDR 80 TDI (000000f904006a956a95);
RUNTEST 144 TCK;
SDR 80 TDI (00000000000000f90400) SMASK (ffffffffffffffffffff) TDO (00000000000000000000) MASK (ffffffffffffffffffff);
"""
(s.FOLDER/'jedec_probe.svf').write_bytes(('\n'.join(base[:11])+'\n'+body+'\n'.join(base[11:])+'\n').encode())
s.impact('jedec_probe','setMode -bs\naddDevice -p 1 -file jedec_probe.svf\nsetCable -p usb21 -baud 1500000\nplay -cont_on_fail -showalltdo\nquit',timeout=60)

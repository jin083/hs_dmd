import run_step as s
head=(s.FOLDER/'id_clean.svf').read_text().splitlines()[:11]
footer=(s.FOLDER/'id_clean.svf').read_text().splitlines()[11:]
def status(value):
    return f"SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (000000a008006a956a95);\nRUNTEST 144 TCK;\nSDR 80 TDI (00000000000000a00800) SMASK (ffffffffffffffffffff) TDO ({value << 24:020x}) MASK (000000000000ff000000);\n"
def command(word):
    return f"SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI ({word});\nRUNTEST 144 TCK;\nRUNTEST 15000 TCK;\n"
body=status(0)+command('0000006010006a956a95')+status(0x40)+command('0000002010006a956a95')+status(0)
(s.FOLDER/'status_probe.svf').write_bytes(('\n'.join(head)+'\n'+body+'\n'.join(footer)+'\n').encode())
s.impact('status_probe','setMode -bs\naddDevice -p 1 -file status_probe.svf\nsetCable -p usb21 -baud 1500000\nplay -cont_on_fail -showalltdo\nquit',timeout=60)

import run_step as s
text='''TRST OFF;
ENDIR IDLE;
ENDDR IDLE;
STATE RESET;
STATE IDLE;
HIR 10 TDI (3FF) SMASK (3FF);
TIR 0;
HDR 1 TDI (0) SMASK (1);
TDR 0;
SIR 10 TDI (3C9) SMASK (3FF);
SDR 32 TDI (00000000) SMASK (FFFFFFFF) TDO (02896093) MASK (0FFFFFFF);
TIR 0;
HIR 0;
TDR 0;
HDR 0;
SIR 20 TDI (FFFFF) SMASK (FFFFF);
SDR 2 TDI (0) SMASK (3);
'''
(s.FOLDER/'id_clean.svf').write_bytes(text.encode('ascii'))
s.impact('play_id_clean','setMode -bs\naddDevice -p 1 -file id_clean.svf\nsetCable -p usb21 -baud 1500000\nplay\nquit',timeout=60)
s.guest('svf_tools','command -v svf2xsvf\nfind /opt/Xilinx/14.7/ISE_DS/ISE/bin -maxdepth 2 -iname "*svf*" -print',timeout=15)

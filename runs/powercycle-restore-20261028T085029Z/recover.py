import run_step as s
s.p.attach_cable(s.p.metadata(s.p.vbox('showvminfo',s.p.VM,'--machinereadable')))
s.impact('identify', '''setMode -bs
setCable -p usb21 -baud 1500000
Identify
saveCdf -file chain.cdf
ReadStatusRegister -p 1
quit''',timeout=60)
s.p.require_lx50_chain((s.FOLDER/'chain.cdf').read_text())
print('EXPECTED_CHAIN_CONFIRMED',flush=True)
import restore_sram

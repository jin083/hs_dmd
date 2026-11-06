setMode -bs
setCable -p usb21 -baud 750000
Identify
saveCdf -file powercycle_chain.cdf
ReadStatusRegister -p 1
quit

setMode -bs
setCable -p usb21 -baud 1500000
Identify
saveCdf -file chain.cdf
ReadStatusRegister -p 1
quit

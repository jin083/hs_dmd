setMode -bs
setCable -p usb21 -baud 1500000
Identify
saveCdf -file slow_chain.cdf
ReadStatusRegister -p 1
quit

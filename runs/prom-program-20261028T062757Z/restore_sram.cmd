setMode -bs
loadCdf -file slow_chain.cdf
setCable -p usb21 -baud 1500000
assignFile -p 1 -file restore_d202.bit
Program -p 1
ReadStatusRegister -p 1
quit

setMode -bs
loadCdf -file slow_chain.cdf
setCable -p usb21 -baud 750000
attachFlash -p 1 -spi S25FL032P
readbackToFile -p 1 -spi S25FL032P -partial 0x38e000 0x2000 -file tail_sample1.mcs
readbackToFile -p 1 -spi S25FL032P -partial 0x38e000 0x2000 -file tail_sample2.mcs
quit

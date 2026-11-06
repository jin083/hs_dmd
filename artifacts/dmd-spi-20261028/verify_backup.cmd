setMode -bs
loadCdf -file slow_chain.cdf
setCable -p usb21 -baud 1500000
attachFlash -p 1 -spi S25FL032P
assignFileToAttachedFlash -p 1 -file original_apps_full.mcs
Verify -p 1 -spionly
quit

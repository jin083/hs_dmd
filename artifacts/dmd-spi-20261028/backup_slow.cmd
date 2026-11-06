setMode -bs
setCable -p usb21 -baud 1500000
Identify
attachFlash -p 1 -spi S25FL032P
readbackToFile -p 1 -spi S25FL032P -file original_apps_full.mcs
quit

setMode -bs
setCable -p auto
Identify
attachFlash -p 1 -spi S25FL032P
readbackToFile -p 1 -spi S25FL032P -file original_apps_1.mcs
quit

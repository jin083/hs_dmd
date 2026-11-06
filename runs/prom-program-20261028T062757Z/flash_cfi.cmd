setMode -bs
setCable -p auto
Identify
attachFlash -p 1 -spi S25FL032P
readCFI -p 1 -spionly
saveCdf -file flash_chain.cdf
quit

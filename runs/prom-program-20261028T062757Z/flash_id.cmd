setMode -bs
setCable -p auto
Identify
attachFlash -p 1 -spi S25FL032P
readIdcode -p 1 -target
saveCdf -file flash_chain.cdf
quit

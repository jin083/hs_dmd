setMode -bs
setCable -p auto
Identify
saveCdf -file status_chain.cdf
ReadStatusRegister -p 1
ReadStatusRegister -p 2
quit

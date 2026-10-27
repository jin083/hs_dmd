setMode -bs
setCable -p auto
Identify
assignFile -p 1 -file appsfpga_repaired_jtag.bit
saveCdf -file program_chain.cdf
Program -p 1
ReadStatusRegister -p 1
quit

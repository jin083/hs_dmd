setMode -bs
setCable -p auto
Identify
assignFile -p 1 -file selected_jtag.bit
Program -p 1
ReadStatusRegister -p 1
quit

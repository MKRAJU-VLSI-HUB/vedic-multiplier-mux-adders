## vedic16.xdc -- constraints for vedic16_top (Kintex-7 xc7k70tfbv676-1)

## 100 MHz clock: the multiplier must settle between the input and output registers
create_clock -period 10.000 -name clk [get_ports clk]

## all user I/O at 3.3 V
set_property IOSTANDARD LVCMOS33 [get_ports -filter {DIRECTION == IN || DIRECTION == OUT}]

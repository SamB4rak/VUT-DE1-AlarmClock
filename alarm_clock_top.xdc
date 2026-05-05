## ============================================================
## Nexys A7-50T - Constraints for alarm_clock_top
## Based on Digilent Nexys A7 master XDC
## ============================================================

## -----------------------------------------------
## Clock signal (100 MHz)
## -----------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}];
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## -----------------------------------------------
## Reset - mapped to SW(15) for convenience
## SW(15) UP = reset active, DOWN = normal run
## -----------------------------------------------
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {rst}];

## -----------------------------------------------
## Push buttons (5-directional pad)
## -----------------------------------------------
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {btnu}];
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {btnd}];
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {btnl}];
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports {btnr}];
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {btnc}];

## -----------------------------------------------
## Mode switch SW(0)
## -----------------------------------------------
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}];

## -----------------------------------------------
## Seven-segment display - cathodes (active-low)
## seg[6]=CA ... seg[0]=CG
## -----------------------------------------------
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}];
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}];
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}];
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}];
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}];
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}];
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}];

## -----------------------------------------------
## Seven-segment display - decimal point DP (active-low)
## Used as the blinking colon indicator
## Pin H15 is the correct DP pin for Nexys A7-50T
## -----------------------------------------------
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {dp}];

## -----------------------------------------------
## Seven-segment display - anodes (active-low, 8 digits)
## an[0]..an[3] = left 4 digits  -> time HH:MM
## an[4]..an[7] = right 4 digits -> alarm HH:MM
## -----------------------------------------------
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {an[0]}];
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {an[1]}];
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {an[2]}];
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {an[3]}];
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {an[4]}];
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {an[5]}];
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {an[6]}];
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports {an[7]}];

## -----------------------------------------------
## Piezo buzzer - connected to Pmod JA, pin 1 (JA1 = C17)
## -----------------------------------------------
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports {piezo}];

## ============================================================
## Nexys A7-50T - Constraints for alarm_clock_top
## Based on Digilent Nexys A7 master XDC
## ============================================================

## -----------------------------------------------
## Clock signal (100 MHz)
## -----------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

## -----------------------------------------------
## Reset - BTNCPUReset (active-high on Nexys A7)
## Use the dedicated CPU_RESETN button? No, we map rst to any push button.
## Here rst is mapped to switch SW[15] for convenience (toggle reset).
## -----------------------------------------------
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {rst}];

## -----------------------------------------------
## Push buttons (5-directional pad)
## btnu = up, btnd = down, btnl = left, btnr = right, btnc = center
## -----------------------------------------------
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {btnu}];
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {btnd}];
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {btnl}];
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports {btnr}];
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {btnc}];

## -----------------------------------------------
## Mode switch SW(0)
## SW(0) = 0 -> RUN / SET_ALARM mode
## SW(0) = 1 -> SET_TIME mode
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
## Seven-segment display - decimal point (active-low)
## Used for colon indication (1 Hz blink on time, always-on on alarm)
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

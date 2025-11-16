## Basys3 Constraint File for Single-Board I2C Demo
## Single Board: I2C Master + 3 Slaves (integrated)
## Clock: 100 MHz
## I2C: Internal bus (no external PMOD connections needed)
##
## Use this for development, testing, and demonstration purposes
## before moving to 2-board configuration

#===============================================================================
# Clock signal
#===============================================================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

#===============================================================================
# Reset (Center button)
#===============================================================================
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

#===============================================================================
# Master Control Interface
#===============================================================================
## Start button (BTNU)
set_property PACKAGE_PIN T18 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]

#===============================================================================
# Switches (SW0-SW15)
# SW[15]: R/W bit
# SW[14:8]: Slave address
# SW[7:0]: TX data / Switch input for slave
#===============================================================================
set_property PACKAGE_PIN V17 [get_ports {SW[0]}]
set_property PACKAGE_PIN V16 [get_ports {SW[1]}]
set_property PACKAGE_PIN W16 [get_ports {SW[2]}]
set_property PACKAGE_PIN W17 [get_ports {SW[3]}]
set_property PACKAGE_PIN W15 [get_ports {SW[4]}]
set_property PACKAGE_PIN V15 [get_ports {SW[5]}]
set_property PACKAGE_PIN W14 [get_ports {SW[6]}]
set_property PACKAGE_PIN W13 [get_ports {SW[7]}]
set_property PACKAGE_PIN V2  [get_ports slave_addr[0]]
set_property PACKAGE_PIN T3  [get_ports slave_addr[1]]
set_property PACKAGE_PIN T2  [get_ports slave_addr[2]]
set_property PACKAGE_PIN R3  [get_ports slave_addr[3]]
set_property PACKAGE_PIN W2  [get_ports slave_addr[4]]
set_property PACKAGE_PIN U1  [get_ports slave_addr[5]]
set_property PACKAGE_PIN T1  [get_ports slave_addr[6]]
set_property PACKAGE_PIN R2  [get_ports rw_bit]

set_property IOSTANDARD LVCMOS33 [get_ports {SW[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_addr[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports rw_bit]

## Note: SW[7:0] is also routed to Switch Slave input

#===============================================================================
# LEDs (LED0-LED15)
# LED[7:0]: LED Slave output / RX data from master
# LED[8]: Busy
# LED[9]: Done
# LED[10]: ACK error
#===============================================================================
set_property PACKAGE_PIN U16 [get_ports {LED[0]}]
set_property PACKAGE_PIN E19 [get_ports {LED[1]}]
set_property PACKAGE_PIN U19 [get_ports {LED[2]}]
set_property PACKAGE_PIN V19 [get_ports {LED[3]}]
set_property PACKAGE_PIN W18 [get_ports {LED[4]}]
set_property PACKAGE_PIN U15 [get_ports {LED[5]}]
set_property PACKAGE_PIN U14 [get_ports {LED[6]}]
set_property PACKAGE_PIN V14 [get_ports {LED[7]}]
set_property PACKAGE_PIN V13 [get_ports busy]
set_property PACKAGE_PIN V3  [get_ports done]
set_property PACKAGE_PIN W3  [get_ports ack_error]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports busy]
set_property IOSTANDARD LVCMOS33 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports ack_error]

#===============================================================================
# 7-Segment Display (FND Slave output)
#===============================================================================
## Segment cathodes (active low)
set_property PACKAGE_PIN W7 [get_ports {SEG[0]}]
set_property PACKAGE_PIN W6 [get_ports {SEG[1]}]
set_property PACKAGE_PIN U8 [get_ports {SEG[2]}]
set_property PACKAGE_PIN V8 [get_ports {SEG[3]}]
set_property PACKAGE_PIN U5 [get_ports {SEG[4]}]
set_property PACKAGE_PIN V5 [get_ports {SEG[5]}]
set_property PACKAGE_PIN U7 [get_ports {SEG[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEG[*]}]

## Digit anodes (active low)
set_property PACKAGE_PIN U2 [get_ports {AN[0]}]
set_property PACKAGE_PIN U4 [get_ports {AN[1]}]
set_property PACKAGE_PIN V4 [get_ports {AN[2]}]
set_property PACKAGE_PIN W4 [get_ports {AN[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AN[*]}]

#===============================================================================
# Debug Outputs (optional - to remaining LEDs)
#===============================================================================
# set_property PACKAGE_PIN U3 [get_ports debug_addr_match_led]
# set_property PACKAGE_PIN P3 [get_ports debug_addr_match_fnd]
# set_property PACKAGE_PIN N3 [get_ports debug_addr_match_sw]
# set_property IOSTANDARD LVCMOS33 [get_ports debug_addr_match_*]

#===============================================================================
# Configuration
#===============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

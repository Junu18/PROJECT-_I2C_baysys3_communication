## Basys3 Constraint File for I2C Master Board (Reference Design)
## Board #1: I2C Master (MicroBlaze + AXI I2C Master IP)
## Clock: 100 MHz
## I2C: SCL=JA1 (output), SDA=JA2 (bidir)
##
## NOTE: This is a REFERENCE constraint file for standalone testing.
## In actual MicroBlaze implementation, use Vivado Block Design
## and let Vivado auto-generate constraints from block design.

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
# I2C Interface (PMOD JA - outputs to slave board)
#===============================================================================
## JA1 = SCL (output to slave board)
set_property PACKAGE_PIN J1 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property PULLUP true [get_ports scl]

## JA2 = SDA (bidirectional)
set_property PACKAGE_PIN L2 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]
set_property PULLUP true [get_ports sda]

#===============================================================================
# Control Button (Start transaction)
#===============================================================================
set_property PACKAGE_PIN T18 [get_ports btn_start]
set_property IOSTANDARD LVCMOS33 [get_ports btn_start]

#===============================================================================
# Switches (SW0-SW15)
# SW[15]: R/W bit
# SW[14:8]: Slave address
# SW[7:0]: TX data
#===============================================================================
set_property PACKAGE_PIN V17 [get_ports {SW[0]}]
set_property PACKAGE_PIN V16 [get_ports {SW[1]}]
set_property PACKAGE_PIN W16 [get_ports {SW[2]}]
set_property PACKAGE_PIN W17 [get_ports {SW[3]}]
set_property PACKAGE_PIN W15 [get_ports {SW[4]}]
set_property PACKAGE_PIN V15 [get_ports {SW[5]}]
set_property PACKAGE_PIN W14 [get_ports {SW[6]}]
set_property PACKAGE_PIN W13 [get_ports {SW[7]}]
set_property PACKAGE_PIN V2  [get_ports {SW[8]}]
set_property PACKAGE_PIN T3  [get_ports {SW[9]}]
set_property PACKAGE_PIN T2  [get_ports {SW[10]}]
set_property PACKAGE_PIN R3  [get_ports {SW[11]}]
set_property PACKAGE_PIN W2  [get_ports {SW[12]}]
set_property PACKAGE_PIN U1  [get_ports {SW[13]}]
set_property PACKAGE_PIN T1  [get_ports {SW[14]}]
set_property PACKAGE_PIN R2  [get_ports {SW[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[*]}]

#===============================================================================
# LEDs (LED0-LED15)
# LED[7:0]: RX data
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
set_property PACKAGE_PIN V13 [get_ports {LED[8]}]
set_property PACKAGE_PIN V3  [get_ports {LED[9]}]
set_property PACKAGE_PIN W3  [get_ports {LED[10]}]
set_property PACKAGE_PIN U3  [get_ports {LED[11]}]
set_property PACKAGE_PIN P3  [get_ports {LED[12]}]
set_property PACKAGE_PIN N3  [get_ports {LED[13]}]
set_property PACKAGE_PIN P1  [get_ports {LED[14]}]
set_property PACKAGE_PIN L1  [get_ports {LED[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}]

#===============================================================================
# Configuration
#===============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

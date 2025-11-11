##==============================================================================
## Basys3 I2C Slave Constraint File
##==============================================================================
## Board: Digilent Basys3 (Artix-7 XC7A35T)
## Purpose: I2C Slave configuration
##==============================================================================

## Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]  # BTNC (Center button)

## LEDs - RX Data Display (LED[7:0])
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {rx_data_led[7]}]

## LEDs - Debug Signals
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports debug_addr_match]  # LED8
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports debug_ack_sent]    # LED9
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports debug_state0]      # LED10
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports debug_state1]      # LED11

## Pmod Header JA - I2C Slave Interface
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports scl]   # JA1 - SCL (input)
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports sda]   # JA2 - SDA (inout)

## Configuration Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Timing Constraints
## I2C signals are asynchronous to system clock
set_false_path -from [get_ports scl] -to [all_registers]
set_false_path -from [get_ports sda] -to [all_registers]
set_false_path -from [get_ports rst_n]

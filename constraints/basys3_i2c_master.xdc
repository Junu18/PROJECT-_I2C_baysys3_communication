##==============================================================================
## Basys3 I2C Master Constraint File
##==============================================================================
## Board: Digilent Basys3 (Artix-7 XC7A35T)
## Purpose: I2C Master configuration
##==============================================================================

## Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset & Control Buttons
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]     # BTNC (Center button)
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports start]     # BTNU (Up button) - Start I2C

## Switches - Slave Address (SW[6:0])
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {slave_addr[6]}]

## Switch - Read/Write Control (SW7)
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports rw_bit]    # 0=Write, 1=Read

## Switches - TX Data (SW[15:8])
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {tx_data[0]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {tx_data[1]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {tx_data[2]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {tx_data[3]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {tx_data[4]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {tx_data[5]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {tx_data[6]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {tx_data[7]}]

## LEDs - TX/RX Data Display (LED[7:0])
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {rx_data[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {rx_data[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {rx_data[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {rx_data[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {rx_data[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {rx_data[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {rx_data[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {rx_data[7]}]

## LEDs - Debug Signals
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports debug_busy]      # LED8
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports debug_ack]       # LED9
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports debug_scl]       # LED10
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports debug_sda_out]   # LED11
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports debug_sda_oe]    # LED12
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports ack_error]       # LED13
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports done]            # LED14
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports busy]            # LED15

## Pmod Header JB - I2C Master Interface
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports scl]   # JB1 - SCL (output)
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports sda]   # JB2 - SDA (inout)

## Configuration Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Timing Constraints
## Constrain I2C SCL to 100 kHz (10 us period)
create_generated_clock -name scl_clk -source [get_pins {scl_reg/C}] -divide_by 1000 [get_ports scl]

## False paths for asynchronous inputs (button debouncing)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports start]
set_false_path -from [get_ports rw_bit]
set_false_path -from [get_ports slave_addr[*]]
set_false_path -from [get_ports tx_data[*]]

## I2C SDA is asynchronous (slave can stretch clock)
set_false_path -from [get_ports sda] -to [all_registers]

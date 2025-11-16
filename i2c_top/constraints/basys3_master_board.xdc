## This file is a general .xdc for the Basys3 rev B board
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

##==============================================================================
## I2C Master Board - Basys3 Constraints
## For board-to-board communication (Master side)
##==============================================================================

## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Switches (slave_addr[6:0] + rw_bit)
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[0]}]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[1]}]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[2]}]
set_property -dict { PACKAGE_PIN W17   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[3]}]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[4]}]
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[5]}]
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports {slave_addr[6]}]
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports rw_bit]

## Switches 8-15 (tx_data[7:0])
set_property -dict { PACKAGE_PIN V2    IOSTANDARD LVCMOS33 } [get_ports {tx_data[0]}]
set_property -dict { PACKAGE_PIN T3    IOSTANDARD LVCMOS33 } [get_ports {tx_data[1]}]
set_property -dict { PACKAGE_PIN T2    IOSTANDARD LVCMOS33 } [get_ports {tx_data[2]}]
set_property -dict { PACKAGE_PIN R3    IOSTANDARD LVCMOS33 } [get_ports {tx_data[3]}]
set_property -dict { PACKAGE_PIN W2    IOSTANDARD LVCMOS33 } [get_ports {tx_data[4]}]
set_property -dict { PACKAGE_PIN U1    IOSTANDARD LVCMOS33 } [get_ports {tx_data[5]}]
set_property -dict { PACKAGE_PIN T1    IOSTANDARD LVCMOS33 } [get_ports {tx_data[6]}]
set_property -dict { PACKAGE_PIN R2    IOSTANDARD LVCMOS33 } [get_ports {tx_data[7]}]

## LEDs (rx_data[7:0])
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports {rx_data[0]}]
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports {rx_data[1]}]
set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports {rx_data[2]}]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports {rx_data[3]}]
set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports {rx_data[4]}]
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports {rx_data[5]}]
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports {rx_data[6]}]
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports {rx_data[7]}]

## Status LEDs
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports busy]
set_property -dict { PACKAGE_PIN V3    IOSTANDARD LVCMOS33 } [get_ports done]
set_property -dict { PACKAGE_PIN W3    IOSTANDARD LVCMOS33 } [get_ports ack_error]

## Buttons
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports rst_n]
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports start]

## PMOD Header JA (I2C Bus)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports sda]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports scl]

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

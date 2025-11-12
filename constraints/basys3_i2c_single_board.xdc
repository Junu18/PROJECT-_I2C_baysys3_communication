##==============================================================================
## Basys3 I2C Single Board Constraint File
##==============================================================================
## Board: Digilent Basys3 (Artix-7 XC7A35T)
## Purpose: Master + Slave on single board (loopback test)
##==============================================================================

## Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset & Control Buttons
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]          # BTNC (Center) - Reset
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_start]      # BTNU (Up) - Start I2C
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btn_mode]       # BTNL (Left) - Display mode
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btn_loopback]   # BTNR (Right) - Loopback enable

## Switches - Configuration
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[0]}]   # SW0
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[1]}]   # SW1
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[2]}]   # SW2
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[3]}]   # SW3
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[4]}]   # SW4
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[5]}]   # SW5
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[6]}]   # SW6
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {sw_tx_data[7]}]   # SW7

set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports sw_rw]             # SW8 - Read/Write (0=Write, 1=Read)
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[0]]  # SW9
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[1]]  # SW10
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[2]]  # SW11
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[3]]  # SW12
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[4]]  # SW13
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[5]]  # SW14
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports sw_slave_addr[6]]  # SW15

## LEDs - Data Display (multiplexed)
## When display_mode=0: Show Master TX data
## When display_mode=1: Show Slave RX data
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led_data[0]}]     # LED0
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led_data[1]}]     # LED1
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led_data[2]}]     # LED2
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led_data[3]}]     # LED3
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led_data[4]}]     # LED4
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led_data[5]}]     # LED5
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led_data[6]}]     # LED6
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led_data[7]}]     # LED7

## LEDs - Status & Debug
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports led_master_busy]   # LED8 - Master busy
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports led_master_done]   # LED9 - Master done
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports led_master_ack]    # LED10 - Master ACK
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports led_slave_match]   # LED11 - Slave addr match
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports led_slave_valid]   # LED12 - Slave data valid
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports led_scl]           # LED13 - SCL monitor
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports led_sda]           # LED14 - SDA monitor
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports led_loopback]      # LED15 - Loopback mode

## Pmod Header JB - I2C External (optional monitoring/external connection)
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports pmod_scl]   # JB1 - SCL
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports pmod_sda]   # JB2 - SDA

## Configuration Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Timing Constraints
## Constrain I2C SCL to 100 kHz (10 us period)
create_generated_clock -name scl_clk -source [get_pins {master/scl_reg/C}] -divide_by 1000 [get_nets scl_internal]

## False paths for asynchronous inputs
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports btn_start]
set_false_path -from [get_ports btn_mode]
set_false_path -from [get_ports btn_loopback]
set_false_path -from [get_ports sw_rw]
set_false_path -from [get_ports sw_tx_data[*]]
set_false_path -from [get_ports sw_slave_addr[*]]

## I2C SDA is asynchronous
set_false_path -from [get_nets sda_internal] -to [all_registers]
set_false_path -from [get_nets pmod_sda] -to [all_registers]

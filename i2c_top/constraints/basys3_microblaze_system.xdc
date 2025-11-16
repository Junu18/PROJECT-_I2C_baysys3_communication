## This file is a constraint file for MicroBlaze + I2C Master system
## Block Design configuration:
##  - MicroBlaze
##  - i2c_master (Custom IP)
##  - AXI GPIO for LED
##  - AXI GPIO for SW
##
## After creating Block Design and HDL Wrapper, apply this constraint file

##==============================================================================
## Clock signal (automatically connected in Block Design)
##==============================================================================
## Note: Clock is usually managed by MicroBlaze clocking wizard
## If you need to constrain external clock:
# set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
# create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

##==============================================================================
## I2C Bus (from i2c_master IP - Make External)
##==============================================================================
## Port names will be like: sda_0, scl_0 (check your wrapper file for exact names)
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports scl_0]
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports sda_0]

##==============================================================================
## LEDs (from AXI GPIO - Make External as output)
##==============================================================================
## Port names will be like: gpio_led_tri_o[15:0] (check your wrapper file)
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[0]}]
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[1]}]
set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[2]}]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[3]}]
set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[4]}]
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[5]}]
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[6]}]
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[7]}]
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[8]}]
set_property -dict { PACKAGE_PIN V3    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[9]}]
set_property -dict { PACKAGE_PIN W3    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[10]}]
set_property -dict { PACKAGE_PIN U3    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[11]}]
set_property -dict { PACKAGE_PIN P3    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[12]}]
set_property -dict { PACKAGE_PIN N3    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[13]}]
set_property -dict { PACKAGE_PIN P1    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[14]}]
set_property -dict { PACKAGE_PIN L1    IOSTANDARD LVCMOS33 } [get_ports {gpio_led_tri_o[15]}]

##==============================================================================
## Switches (from AXI GPIO - Make External as input)
##==============================================================================
## Port names will be like: gpio_sw_tri_i[15:0] (check your wrapper file)
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[0]}]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[1]}]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[2]}]
set_property -dict { PACKAGE_PIN W17   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[3]}]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[4]}]
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[5]}]
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[6]}]
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[7]}]
set_property -dict { PACKAGE_PIN V2    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[8]}]
set_property -dict { PACKAGE_PIN T3    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[9]}]
set_property -dict { PACKAGE_PIN T2    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[10]}]
set_property -dict { PACKAGE_PIN R3    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[11]}]
set_property -dict { PACKAGE_PIN W2    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[12]}]
set_property -dict { PACKAGE_PIN U1    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[13]}]
set_property -dict { PACKAGE_PIN T1    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[14]}]
set_property -dict { PACKAGE_PIN R2    IOSTANDARD LVCMOS33 } [get_ports {gpio_sw_tri_i[15]}]

##==============================================================================
## Configuration options
##==============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options for QSPI boot
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

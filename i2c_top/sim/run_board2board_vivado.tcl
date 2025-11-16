#==============================================================================
# Vivado TCL Script for Board-to-Board I2C Communication Test
# Run in Vivado TCL Console
#==============================================================================

puts "================================================================================"
puts "         BOARD-TO-BOARD I2C COMMUNICATION TEST (Vivado)"
puts "================================================================================"

# Create project
create_project -force board2board_sim ./vivado_sim -part xc7a35tcpg236-1

# Add RTL files
add_files -norecurse {
    ../rtl/master/i2c_master.sv
    ../rtl/slaves/i2c_led_slave.sv
    ../rtl/slaves/i2c_fnd_slave.sv
    ../rtl/slaves/i2c_switch_slave.sv
    ../rtl/integration/i2c_master_board.sv
    ../rtl/integration/i2c_slave_board.sv
}

# Add testbench
add_files -fileset sim_1 -norecurse ../tb/i2c_board2board_tb.sv

# Set top module
set_property top i2c_board2board_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set simulation runtime
set_property -name {xsim.simulate.runtime} -value {50ms} -objects [get_filesets sim_1]

puts ""
puts "Project created successfully!"
puts "Launching simulation..."
puts ""

# Launch simulation
launch_simulation

puts ""
puts "================================================================================"
puts "Simulation launched. Check TCL Console for test results."
puts "================================================================================"

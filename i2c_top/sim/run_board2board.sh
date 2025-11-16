#!/bin/bash

#==============================================================================
# Board-to-Board I2C Communication Test
# Tests Master Board <--PMOD--> Slave Board scenario
#==============================================================================

echo "================================================================================"
echo "         BOARD-TO-BOARD I2C COMMUNICATION TEST"
echo "         Master Board <--PMOD cable--> Slave Board"
echo "================================================================================"
echo ""

# Clean previous builds
rm -f i2c_board2board_tb i2c_board2board_tb.vcd

# Compile with Icarus Verilog
echo "Compiling RTL and testbench..."
iverilog -g2012 -o i2c_board2board_tb \
    ../rtl/master/i2c_master.sv \
    ../rtl/slaves/i2c_led_slave.sv \
    ../rtl/slaves/i2c_fnd_slave.sv \
    ../rtl/slaves/i2c_switch_slave.sv \
    ../rtl/integration/i2c_master_board.sv \
    ../rtl/integration/i2c_slave_board.sv \
    ../tb/i2c_board2board_tb.sv

if [ $? -ne 0 ]; then
    echo "✗ Compilation failed!"
    exit 1
fi

echo "Compilation successful!"
echo ""

# Run simulation
echo "Running simulation..."
echo "================================================================================"
vvp i2c_board2board_tb

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================================================"
    echo "✓ Board-to-board simulation completed"
    echo "================================================================================"
    echo ""
    echo "To view waveform:"
    echo "  gtkwave i2c_board2board_tb.vcd"
    echo ""
else
    echo "✗ Simulation failed!"
    exit 1
fi

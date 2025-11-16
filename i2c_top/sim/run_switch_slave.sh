#!/bin/bash

#==============================================================================
# Simulation script for I2C Switch Slave
#==============================================================================

echo "========================================="
echo "I2C Switch Slave Simulation"
echo "========================================="

# Clean previous builds
rm -f i2c_switch_slave_tb i2c_switch_slave_tb.vcd

# Compile with Icarus Verilog
echo "Compiling..."
iverilog -g2012 -o i2c_switch_slave_tb \
    ../rtl/slaves/i2c_switch_slave.sv \
    ../tb/i2c_switch_slave_tb.sv

if [ $? -ne 0 ]; then
    echo "✗ Compilation failed!"
    exit 1
fi

# Run simulation
echo "Running simulation..."
vvp i2c_switch_slave_tb

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✓ Simulation completed"
    echo "========================================="
    echo ""
    echo "To view waveform:"
    echo "  gtkwave i2c_switch_slave_tb.vcd"
else
    echo "✗ Simulation failed!"
    exit 1
fi

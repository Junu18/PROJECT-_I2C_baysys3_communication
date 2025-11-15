#!/bin/bash

#==============================================================================
# Simulation script for I2C Multi-Slave System
#==============================================================================

echo "========================================="
echo "I2C Multi-Slave System Simulation"
echo "Master + 3 Slaves Integration Test"
echo "========================================="

# Clean previous builds
rm -f i2c_system_tb i2c_system_tb.vcd

# Compile with Icarus Verilog
echo "Compiling..."
iverilog -g2012 -o i2c_system_tb \
    ../rtl/master/i2c_master.sv \
    ../rtl/slaves/i2c_led_slave.sv \
    ../rtl/slaves/i2c_fnd_slave.sv \
    ../rtl/slaves/i2c_switch_slave.sv \
    ../rtl/integration/i2c_system_top.sv \
    ../tb/i2c_system_tb.sv

if [ $? -ne 0 ]; then
    echo "✗ Compilation failed!"
    exit 1
fi

# Run simulation
echo "Running simulation..."
vvp i2c_system_tb

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✓ System Simulation completed"
    echo "========================================="
    echo ""
    echo "To view waveform:"
    echo "  gtkwave i2c_system_tb.vcd"
else
    echo "✗ Simulation failed!"
    exit 1
fi

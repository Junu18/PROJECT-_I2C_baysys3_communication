#!/bin/bash

#==============================================================================
# Run All I2C Tests
#==============================================================================

echo "========================================="
echo "Running All I2C Tests"
echo "========================================="
echo ""

# Track results
PASS_COUNT=0
FAIL_COUNT=0

# Test 1: LED Slave
echo ">>> Test 1/4: LED Slave"
./run_led_slave.sh > /tmp/led_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ LED Slave test passed"
    ((PASS_COUNT++))
else
    echo "✗ LED Slave test failed (see /tmp/led_test.log)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 2: FND Slave
echo ">>> Test 2/4: FND Slave"
./run_fnd_slave.sh > /tmp/fnd_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ FND Slave test passed"
    ((PASS_COUNT++))
else
    echo "✗ FND Slave test failed (see /tmp/fnd_test.log)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 3: Switch Slave
echo ">>> Test 3/4: Switch Slave"
./run_switch_slave.sh > /tmp/switch_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Switch Slave test passed"
    ((PASS_COUNT++))
else
    echo "✗ Switch Slave test failed (see /tmp/switch_test.log)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 4: System Integration
echo ">>> Test 4/4: System Integration"
./run_system.sh > /tmp/system_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ System Integration test passed"
    ((PASS_COUNT++))
else
    echo "✗ System Integration test failed (see /tmp/system_test.log)"
    ((FAIL_COUNT++))
fi
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Passed: $PASS_COUNT/4"
echo "Failed: $FAIL_COUNT/4"
echo "========================================="

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ ALL TESTS PASSED!"
    exit 0
else
    echo "✗ SOME TESTS FAILED!"
    exit 1
fi

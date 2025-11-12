/**
 * @file main.c
 * @brief I2C Master/Slave Test Application for MicroBlaze
 *
 * This example demonstrates:
 * 1. I2C Master writing data to I2C Slave
 * 2. I2C Master reading data from I2C Slave
 * 3. Interrupt-driven data reception on Slave
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xintc.h"
#include "i2c_driver.h"

//==============================================================================
// Base Addresses (update these based on your Vivado design)
//==============================================================================
#ifndef XPAR_AXI_I2C_MASTER_0_BASEADDR
#define I2C_MASTER_BASEADDR     0x44A00000  // Example address
#else
#define I2C_MASTER_BASEADDR     XPAR_AXI_I2C_MASTER_0_BASEADDR
#endif

#ifndef XPAR_AXI_I2C_SLAVE_0_BASEADDR
#define I2C_SLAVE_BASEADDR      0x44A10000  // Example address
#else
#define I2C_SLAVE_BASEADDR      XPAR_AXI_I2C_SLAVE_0_BASEADDR
#endif

//==============================================================================
// Global Variables
//==============================================================================
static volatile uint8_t slave_rx_data = 0;
static volatile int slave_data_received = 0;

//==============================================================================
// Interrupt Handler (if using interrupts)
//==============================================================================
void i2c_slave_interrupt_handler(void *callback_ref)
{
    uint8_t data;

    // Read data from slave
    if (i2c_slave_get_rx_data(I2C_SLAVE_BASEADDR, &data)) {
        slave_rx_data = data;
        slave_data_received = 1;
        xil_printf("Slave Interrupt: Received 0x%02X\r\n", data);
    }
}

//==============================================================================
// Test Functions
//==============================================================================

void test_master_write_slave_read(void)
{
    uint8_t test_data = 0xA5;
    uint8_t rx_data;
    int timeout = 1000;

    xil_printf("\r\n=== Test 1: Master Write -> Slave Read ===\r\n");

    // Reset flag
    slave_data_received = 0;

    // Master writes data
    xil_printf("Master: Writing 0x%02X to slave 0x%02X...\r\n",
               test_data, I2C_DEFAULT_SLAVE_ADDR);

    if (i2c_master_write_byte(I2C_MASTER_BASEADDR, I2C_DEFAULT_SLAVE_ADDR, test_data)) {
        xil_printf("Master: Write successful (ACK received)\r\n");
    } else {
        xil_printf("Master: Write failed (NACK or timeout)\r\n");
        return;
    }

    // Wait for slave to receive data (with timeout)
    while (!slave_data_received && timeout-- > 0) {
        // Poll slave status
        if (i2c_slave_get_rx_data(I2C_SLAVE_BASEADDR, &rx_data)) {
            slave_rx_data = rx_data;
            slave_data_received = 1;
        }
        usleep(1000); // 1ms delay
    }

    if (slave_data_received) {
        xil_printf("Slave: Received 0x%02X\r\n", slave_rx_data);

        if (slave_rx_data == test_data) {
            xil_printf("TEST PASSED: Data matches!\r\n");
        } else {
            xil_printf("TEST FAILED: Data mismatch (expected 0x%02X, got 0x%02X)\r\n",
                       test_data, slave_rx_data);
        }
    } else {
        xil_printf("TEST FAILED: Slave did not receive data (timeout)\r\n");
    }
}

void test_master_read_slave_write(void)
{
    uint8_t slave_tx = 0x3C;
    uint8_t master_rx;

    xil_printf("\r\n=== Test 2: Master Read <- Slave Write ===\r\n");

    // Slave prepares data to send
    xil_printf("Slave: Setting TX data to 0x%02X\r\n", slave_tx);
    i2c_slave_set_tx_data(I2C_SLAVE_BASEADDR, slave_tx);

    // Master reads data
    xil_printf("Master: Reading from slave 0x%02X...\r\n", I2C_DEFAULT_SLAVE_ADDR);

    if (i2c_master_read_byte(I2C_MASTER_BASEADDR, I2C_DEFAULT_SLAVE_ADDR, &master_rx)) {
        xil_printf("Master: Read successful, received 0x%02X\r\n", master_rx);

        if (master_rx == slave_tx) {
            xil_printf("TEST PASSED: Data matches!\r\n");
        } else {
            xil_printf("TEST FAILED: Data mismatch (expected 0x%02X, got 0x%02X)\r\n",
                       slave_tx, master_rx);
        }
    } else {
        xil_printf("Master: Read failed (NACK or timeout)\r\n");
        xil_printf("TEST FAILED\r\n");
    }
}

void test_multiple_transfers(void)
{
    int i;
    uint8_t data;
    int pass_count = 0;

    xil_printf("\r\n=== Test 3: Multiple Sequential Writes ===\r\n");

    for (i = 0; i < 5; i++) {
        data = 0x10 + i;

        xil_printf("Transfer %d: Writing 0x%02X...", i, data);

        if (i2c_master_write_byte(I2C_MASTER_BASEADDR, I2C_DEFAULT_SLAVE_ADDR, data)) {
            xil_printf("OK\r\n");
            pass_count++;
        } else {
            xil_printf("FAILED\r\n");
        }

        usleep(10000); // 10ms delay between transfers
    }

    xil_printf("Result: %d/%d transfers successful\r\n", pass_count, 5);
}

//==============================================================================
// Main Function
//==============================================================================
int main(void)
{
    init_platform();

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  I2C Master/Slave Test Application    \r\n");
    xil_printf("========================================\r\n");
    xil_printf("Master Base Address: 0x%08X\r\n", I2C_MASTER_BASEADDR);
    xil_printf("Slave Base Address:  0x%08X\r\n", I2C_SLAVE_BASEADDR);
    xil_printf("Slave Address (7-bit): 0x%02X\r\n", I2C_DEFAULT_SLAVE_ADDR);
    xil_printf("========================================\r\n");

    // Initialize I2C Slave
    xil_printf("\r\nInitializing I2C Slave...\r\n");
    i2c_slave_init(I2C_SLAVE_BASEADDR, I2C_DEFAULT_SLAVE_ADDR);
    xil_printf("Slave initialized with address 0x%02X\r\n", I2C_DEFAULT_SLAVE_ADDR);

    // Run tests
    test_master_write_slave_read();
    test_master_read_slave_write();
    test_multiple_transfers();

    xil_printf("\r\n========================================\r\n");
    xil_printf("All tests completed\r\n");
    xil_printf("========================================\r\n");

    cleanup_platform();
    return 0;
}

/**
 * @file i2c_master.c
 * @brief I2C Master Driver Implementation
 */

#include "i2c_master.h"
#include "xil_printf.h"

//==============================================================================
// Helper Functions
//==============================================================================

/**
 * @brief Wait for I2C transaction to complete
 */
int i2c_wait_done(void)
{
    u32 status;
    u32 timeout = I2C_TIMEOUT_CYCLES;

    // Wait for busy flag to clear
    while (timeout > 0) {
        status = Xil_In32(I2C_MASTER_BASEADDR + I2C_STATUS_REG_OFFSET);

        if (!(status & I2C_STATUS_BUSY)) {
            // Transaction complete, check for errors
            if (status & I2C_STATUS_ACK_ERROR) {
                return -2;  // ACK error
            }
            return 0;  // Success
        }
        timeout--;
    }

    return -1;  // Timeout
}

//==============================================================================
// Public Functions
//==============================================================================

void i2c_init(void)
{
    // No initialization needed for current design
    xil_printf("I2C Master initialized at 0x%08X\r\n", I2C_MASTER_BASEADDR);
}

int i2c_write_byte(u8 slave_addr, u8 data)
{
    u32 ctrl_value;

    // Build control register value:
    // [15:8] = tx_data
    // [7:1]  = slave_addr
    // [0]    = rw_bit (0 for write)
    ctrl_value = ((u32)data << 8) | ((u32)slave_addr << 1) | I2C_WRITE;

    // Write to control register (triggers I2C transaction)
    Xil_Out32(I2C_MASTER_BASEADDR + I2C_CTRL_REG_OFFSET, ctrl_value);

    // Wait for completion
    return i2c_wait_done();
}

int i2c_read_byte(u8 slave_addr, u8 *data)
{
    u32 ctrl_value;
    u32 rx_data;
    int status;

    // Build control register value:
    // [7:1] = slave_addr
    // [0]   = rw_bit (1 for read)
    ctrl_value = ((u32)slave_addr << 1) | I2C_READ;

    // Write to control register (triggers I2C transaction)
    Xil_Out32(I2C_MASTER_BASEADDR + I2C_CTRL_REG_OFFSET, ctrl_value);

    // Wait for completion
    status = i2c_wait_done();

    if (status == 0) {
        // Read received data
        rx_data = Xil_In32(I2C_MASTER_BASEADDR + I2C_RXDATA_REG_OFFSET);
        *data = (u8)(rx_data & 0xFF);
    }

    return status;
}

void i2c_print_status(int status)
{
    switch (status) {
        case 0:
            xil_printf("Success\r\n");
            break;
        case -1:
            xil_printf("ERROR: Timeout\r\n");
            break;
        case -2:
            xil_printf("ERROR: NACK received\r\n");
            break;
        default:
            xil_printf("ERROR: Unknown error code %d\r\n", status);
            break;
    }
}

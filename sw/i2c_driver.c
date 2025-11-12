/**
 * @file i2c_driver.c
 * @brief Simple I2C Master/Slave Driver Implementation
 */

#include "i2c_driver.h"
#include "xil_io.h"      // For Xil_In32/Xil_Out32 if using Xilinx SDK
#include "sleep.h"       // For usleep

//==============================================================================
// I2C Master Functions
//==============================================================================

bool i2c_master_write_byte(uint32_t base_addr, uint8_t slave_addr, uint8_t data)
{
    uint32_t status;

    // Check if busy
    if (i2c_master_is_busy(base_addr)) {
        return false;
    }

    // Configure for write operation (R/W = 0)
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_CONFIG_REG, 0x00);

    // Set slave address
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_ADDR_REG, slave_addr);

    // Set data to transmit
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_TXDATA_REG, data);

    // Start transaction
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_CTRL_REG, I2C_MASTER_CTRL_START);

    // Wait for completion (with timeout)
    if (!i2c_master_wait_done(base_addr, 10000)) {  // 10ms timeout
        return false;
    }

    // Check status
    status = I2C_MASTER_READ_REG(base_addr, I2C_MASTER_STAT_REG);

    // Return true if no NACK
    return !(status & I2C_MASTER_STAT_NACK);
}

bool i2c_master_read_byte(uint32_t base_addr, uint8_t slave_addr, uint8_t *data)
{
    uint32_t status;

    // Check if busy
    if (i2c_master_is_busy(base_addr)) {
        return false;
    }

    // Configure for read operation (R/W = 1)
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_CONFIG_REG, I2C_MASTER_CONFIG_RW);

    // Set slave address
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_ADDR_REG, slave_addr);

    // Start transaction
    I2C_MASTER_WRITE_REG(base_addr, I2C_MASTER_CTRL_REG, I2C_MASTER_CTRL_START);

    // Wait for completion (with timeout)
    if (!i2c_master_wait_done(base_addr, 10000)) {  // 10ms timeout
        return false;
    }

    // Check status
    status = I2C_MASTER_READ_REG(base_addr, I2C_MASTER_STAT_REG);

    if (status & I2C_MASTER_STAT_NACK) {
        return false;
    }

    // Read received data
    *data = (uint8_t)(I2C_MASTER_READ_REG(base_addr, I2C_MASTER_RXDATA_REG) & 0xFF);

    return true;
}

bool i2c_master_is_busy(uint32_t base_addr)
{
    uint32_t status = I2C_MASTER_READ_REG(base_addr, I2C_MASTER_STAT_REG);
    return (status & I2C_MASTER_STAT_BUSY) != 0;
}

bool i2c_master_wait_done(uint32_t base_addr, uint32_t timeout_us)
{
    uint32_t status;
    uint32_t elapsed = 0;

    while (elapsed < timeout_us || timeout_us == 0) {
        status = I2C_MASTER_READ_REG(base_addr, I2C_MASTER_STAT_REG);

        // Check if done
        if (status & I2C_MASTER_STAT_DONE) {
            return true;
        }

        // Check if not busy (transaction ended)
        if (!(status & I2C_MASTER_STAT_BUSY)) {
            return true;
        }

        // Wait 1us
        usleep(1);
        elapsed++;

        // Break if timeout is 0 (infinite wait) and done
        if (timeout_us == 0 && (status & I2C_MASTER_STAT_DONE)) {
            break;
        }
    }

    return false; // Timeout
}

//==============================================================================
// I2C Slave Functions
//==============================================================================

void i2c_slave_init(uint32_t base_addr, uint8_t slave_addr)
{
    // Set slave address
    I2C_SLAVE_WRITE_REG(base_addr, I2C_SLAVE_ADDR_REG, slave_addr);

    // Initialize TX data to 0
    I2C_SLAVE_WRITE_REG(base_addr, I2C_SLAVE_TXDATA_REG, 0x00);
}

void i2c_slave_set_tx_data(uint32_t base_addr, uint8_t data)
{
    I2C_SLAVE_WRITE_REG(base_addr, I2C_SLAVE_TXDATA_REG, data);
}

bool i2c_slave_get_rx_data(uint32_t base_addr, uint8_t *data)
{
    uint32_t status;

    // Check if new data available
    status = I2C_SLAVE_READ_REG(base_addr, I2C_SLAVE_STAT_REG);

    if (status & I2C_SLAVE_STAT_DATA_VALID) {
        // Read received data
        *data = (uint8_t)(I2C_SLAVE_READ_REG(base_addr, I2C_SLAVE_RXDATA_REG) & 0xFF);
        return true;
    }

    return false;
}

bool i2c_slave_data_available(uint32_t base_addr)
{
    uint32_t status = I2C_SLAVE_READ_REG(base_addr, I2C_SLAVE_STAT_REG);
    return (status & I2C_SLAVE_STAT_DATA_VALID) != 0;
}

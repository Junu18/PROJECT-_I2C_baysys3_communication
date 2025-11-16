/**
 * @file i2c_driver.c
 * @brief I2C Master Driver Implementation
 */

#include "i2c_driver.h"
#include "i2c_regs.h"
#include <stdint.h>
#include <stddef.h>

//==============================================================================
// Global Variables
//==============================================================================
volatile uint32_t* i2c_base = NULL;

//==============================================================================
// Private Functions
//==============================================================================

/**
 * @brief Delay function (simple loop-based delay)
 * @param us Microseconds to delay
 */
static void delay_us(uint32_t us) {
    // Assuming 100 MHz clock, approximately 100 cycles per microsecond
    // Adjust this value based on actual clock frequency
    volatile uint32_t count = us * 25;  // Rough approximation
    while (count--);
}

/**
 * @brief Wait for I2C transaction to complete
 * @param timeout_us Timeout in microseconds (0 = infinite)
 * @return 0 on success, -1 on timeout
 */
int i2c_wait_done(uint32_t timeout_us) {
    uint32_t elapsed = 0;

    while (i2c_is_busy()) {
        delay_us(1);
        elapsed++;

        if (timeout_us > 0 && elapsed >= timeout_us) {
            return I2C_ERR_TIMEOUT;
        }
    }

    return I2C_SUCCESS;
}

//==============================================================================
// Public Functions
//==============================================================================

/**
 * @brief Initialize I2C driver
 */
void i2c_init(uint32_t base_addr) {
    i2c_base = (volatile uint32_t*)base_addr;

    // Wait for any ongoing transaction to complete
    i2c_wait_done(10000);  // 10ms timeout
}

/**
 * @brief Write one byte to I2C slave
 */
int i2c_write(uint8_t slave_addr, uint8_t data) {
    if (i2c_base == NULL) {
        return I2C_ERR_BUSY;
    }

    // Check if already busy
    if (i2c_is_busy()) {
        return I2C_ERR_BUSY;
    }

    // Set slave address (7-bit address, R/W bit = 0 for write)
    I2C_WRITE_REG(I2C_REG_SLAVE_ADDR, slave_addr);

    // Set transmit data
    I2C_WRITE_REG(I2C_REG_TX_DATA, data);

    // Start transaction (write mode)
    I2C_WRITE_REG(I2C_REG_CONTROL, I2C_CTRL_START);

    // Wait for completion
    int result = i2c_wait_done(10000);  // 10ms timeout
    if (result != I2C_SUCCESS) {
        return result;
    }

    // Check for ACK error
    if (i2c_has_ack_error()) {
        return I2C_ERR_NACK;
    }

    return I2C_SUCCESS;
}

/**
 * @brief Read one byte from I2C slave
 */
int i2c_read(uint8_t slave_addr, uint8_t *data) {
    if (i2c_base == NULL || data == NULL) {
        return I2C_ERR_BUSY;
    }

    // Check if already busy
    if (i2c_is_busy()) {
        return I2C_ERR_BUSY;
    }

    // Set slave address (7-bit address, R/W bit = 1 for read)
    I2C_WRITE_REG(I2C_REG_SLAVE_ADDR, slave_addr);

    // Start transaction (read mode)
    I2C_WRITE_REG(I2C_REG_CONTROL, I2C_CTRL_START | I2C_CTRL_RW_BIT);

    // Wait for completion
    int result = i2c_wait_done(10000);  // 10ms timeout
    if (result != I2C_SUCCESS) {
        return result;
    }

    // Check for ACK error
    if (i2c_has_ack_error()) {
        return I2C_ERR_NACK;
    }

    // Read received data
    *data = (uint8_t)I2C_READ_REG(I2C_REG_RX_DATA);

    return I2C_SUCCESS;
}

/**
 * @brief Write to LED slave
 */
int i2c_write_led(uint8_t value) {
    return i2c_write(I2C_ADDR_LED, value);
}

/**
 * @brief Write to FND slave
 */
int i2c_write_fnd(uint8_t digit) {
    // Ensure digit is 0-F
    digit &= 0x0F;
    return i2c_write(I2C_ADDR_FND, digit);
}

/**
 * @brief Read from Switch slave
 */
int i2c_read_switch(uint8_t *value) {
    return i2c_read(I2C_ADDR_SWITCH, value);
}

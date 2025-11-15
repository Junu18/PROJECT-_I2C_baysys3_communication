/**
 * @file i2c_driver.h
 * @brief I2C Master Driver API
 *
 * High-level driver for AXI I2C Master IP
 */

#ifndef I2C_DRIVER_H
#define I2C_DRIVER_H

#include <stdint.h>

//==============================================================================
// I2C Slave Addresses
//==============================================================================
#define I2C_ADDR_LED        0x55    // LED Slave (Write-only)
#define I2C_ADDR_FND        0x56    // 7-Segment Display Slave (Write-only)
#define I2C_ADDR_SWITCH     0x57    // Switch Slave (Read-only)

//==============================================================================
// Error Codes
//==============================================================================
#define I2C_SUCCESS         0
#define I2C_ERR_TIMEOUT     -1
#define I2C_ERR_NACK        -2
#define I2C_ERR_BUSY        -3

//==============================================================================
// Driver Functions
//==============================================================================

/**
 * @brief Initialize I2C driver
 * @param base_addr Base address of AXI I2C IP (from Vivado)
 */
void i2c_init(uint32_t base_addr);

/**
 * @brief Write one byte to I2C slave
 * @param slave_addr 7-bit slave address
 * @param data Data byte to write
 * @return 0 on success, negative error code on failure
 */
int i2c_write(uint8_t slave_addr, uint8_t data);

/**
 * @brief Read one byte from I2C slave
 * @param slave_addr 7-bit slave address
 * @param data Pointer to store received data
 * @return 0 on success, negative error code on failure
 */
int i2c_read(uint8_t slave_addr, uint8_t *data);

/**
 * @brief Write to LED slave (convenience function)
 * @param value LED pattern (8 bits)
 * @return 0 on success, negative error code on failure
 */
int i2c_write_led(uint8_t value);

/**
 * @brief Write to FND slave (convenience function)
 * @param digit Hex digit to display (0x00-0x0F)
 * @return 0 on success, negative error code on failure
 */
int i2c_write_fnd(uint8_t digit);

/**
 * @brief Read from Switch slave (convenience function)
 * @param value Pointer to store switch value
 * @return 0 on success, negative error code on failure
 */
int i2c_read_switch(uint8_t *value);

#endif // I2C_DRIVER_H

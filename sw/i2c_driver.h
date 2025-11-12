/**
 * @file i2c_driver.h
 * @brief Simple I2C Master/Slave Driver for MicroBlaze
 *
 * Provides high-level functions for I2C communication
 */

#ifndef I2C_DRIVER_H
#define I2C_DRIVER_H

#include <stdint.h>
#include <stdbool.h>
#include "i2c_regs.h"

//==============================================================================
// I2C Master Functions
//==============================================================================

/**
 * @brief Write a byte to I2C slave
 * @param base_addr Base address of I2C Master peripheral
 * @param slave_addr 7-bit slave address
 * @param data Data byte to write
 * @return true if successful (ACK received), false otherwise
 */
bool i2c_master_write_byte(uint32_t base_addr, uint8_t slave_addr, uint8_t data);

/**
 * @brief Read a byte from I2C slave
 * @param base_addr Base address of I2C Master peripheral
 * @param slave_addr 7-bit slave address
 * @param data Pointer to store received data
 * @return true if successful (ACK received), false otherwise
 */
bool i2c_master_read_byte(uint32_t base_addr, uint8_t slave_addr, uint8_t *data);

/**
 * @brief Check if I2C master is busy
 * @param base_addr Base address of I2C Master peripheral
 * @return true if busy, false if idle
 */
bool i2c_master_is_busy(uint32_t base_addr);

/**
 * @brief Wait for I2C master to complete transaction
 * @param base_addr Base address of I2C Master peripheral
 * @param timeout_us Timeout in microseconds (0 = no timeout)
 * @return true if completed, false if timeout
 */
bool i2c_master_wait_done(uint32_t base_addr, uint32_t timeout_us);

//==============================================================================
// I2C Slave Functions
//==============================================================================

/**
 * @brief Initialize I2C slave with address
 * @param base_addr Base address of I2C Slave peripheral
 * @param slave_addr 7-bit slave address
 */
void i2c_slave_init(uint32_t base_addr, uint8_t slave_addr);

/**
 * @brief Set data to be transmitted when master reads
 * @param base_addr Base address of I2C Slave peripheral
 * @param data Data byte to transmit
 */
void i2c_slave_set_tx_data(uint32_t base_addr, uint8_t data);

/**
 * @brief Get received data from master
 * @param base_addr Base address of I2C Slave peripheral
 * @param data Pointer to store received data
 * @return true if new data available, false otherwise
 */
bool i2c_slave_get_rx_data(uint32_t base_addr, uint8_t *data);

/**
 * @brief Check if new data has been received
 * @param base_addr Base address of I2C Slave peripheral
 * @return true if new data available, false otherwise
 */
bool i2c_slave_data_available(uint32_t base_addr);

#endif // I2C_DRIVER_H

/**
 * @file i2c_regs.h
 * @brief AXI I2C Master Register Definitions
 *
 * Register map for custom AXI I2C Master IP
 * Base address will be defined in Vivado block design
 */

#ifndef I2C_REGS_H
#define I2C_REGS_H

#include <stdint.h>

//==============================================================================
// Register Offsets (relative to base address)
//==============================================================================

// Control/Status Registers
#define I2C_REG_CONTROL     0x00    // Control register
#define I2C_REG_STATUS      0x04    // Status register
#define I2C_REG_SLAVE_ADDR  0x08    // 7-bit slave address + R/W bit
#define I2C_REG_TX_DATA     0x0C    // Transmit data register
#define I2C_REG_RX_DATA     0x10    // Receive data register

//==============================================================================
// Control Register Bits
//==============================================================================
#define I2C_CTRL_START      (1 << 0)    // Start I2C transaction (write 1)
#define I2C_CTRL_RW_BIT     (1 << 1)    // R/W bit: 0=Write, 1=Read

//==============================================================================
// Status Register Bits
//==============================================================================
#define I2C_STAT_BUSY       (1 << 0)    // Transaction in progress
#define I2C_STAT_DONE       (1 << 1)    // Transaction completed
#define I2C_STAT_ACK_ERROR  (1 << 2)    // NACK received or error

//==============================================================================
// I2C Slave Addresses
//==============================================================================
#define I2C_ADDR_LED        0x55    // LED Slave
#define I2C_ADDR_FND        0x56    // 7-Segment Display Slave
#define I2C_ADDR_SWITCH     0x57    // Switch Slave

//==============================================================================
// Register Access Macros
//==============================================================================

// Define I2C base address (will be set by Vivado)
// Example: #define I2C_BASE_ADDR 0x44A00000
extern volatile uint32_t* i2c_base;

// Write to register
#define I2C_WRITE_REG(offset, value) \
    (*(volatile uint32_t*)((uint8_t*)i2c_base + (offset)) = (value))

// Read from register
#define I2C_READ_REG(offset) \
    (*(volatile uint32_t*)((uint8_t*)i2c_base + (offset)))

//==============================================================================
// Helper Functions
//==============================================================================

/**
 * @brief Check if I2C master is busy
 * @return 1 if busy, 0 if idle
 */
static inline int i2c_is_busy(void) {
    return (I2C_READ_REG(I2C_REG_STATUS) & I2C_STAT_BUSY) ? 1 : 0;
}

/**
 * @brief Check if last transaction had ACK error
 * @return 1 if error, 0 if no error
 */
static inline int i2c_has_ack_error(void) {
    return (I2C_READ_REG(I2C_REG_STATUS) & I2C_STAT_ACK_ERROR) ? 1 : 0;
}

/**
 * @brief Wait for I2C transaction to complete
 * @param timeout_us Timeout in microseconds (0 = no timeout)
 * @return 0 on success, -1 on timeout
 */
int i2c_wait_done(uint32_t timeout_us);

#endif // I2C_REGS_H

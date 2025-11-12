/**
 * @file i2c_regs.h
 * @brief I2C Master/Slave Register Definitions
 *
 * Register map for AXI-Lite I2C Master and Slave cores
 */

#ifndef I2C_REGS_H
#define I2C_REGS_H

#include <stdint.h>

//==============================================================================
// I2C Master Register Offsets
//==============================================================================
#define I2C_MASTER_CTRL_REG     0x00    // Control Register (W)
#define I2C_MASTER_STAT_REG     0x04    // Status Register (R)
#define I2C_MASTER_ADDR_REG     0x08    // Slave Address (W)
#define I2C_MASTER_TXDATA_REG   0x0C    // Transmit Data (W)
#define I2C_MASTER_RXDATA_REG   0x10    // Receive Data (R)
#define I2C_MASTER_CONFIG_REG   0x14    // Configuration (W)

// CTRL Register Bits
#define I2C_MASTER_CTRL_START   (1 << 0)    // Start I2C transaction

// STAT Register Bits
#define I2C_MASTER_STAT_BUSY    (1 << 0)    // Transaction in progress
#define I2C_MASTER_STAT_NACK    (1 << 1)    // NACK received
#define I2C_MASTER_STAT_DONE    (1 << 2)    // Transaction complete

// CONFIG Register Bits
#define I2C_MASTER_CONFIG_RW    (1 << 0)    // 0=Write, 1=Read

//==============================================================================
// I2C Slave Register Offsets
//==============================================================================
#define I2C_SLAVE_CTRL_REG      0x00    // Control Register (W)
#define I2C_SLAVE_STAT_REG      0x04    // Status Register (R)
#define I2C_SLAVE_ADDR_REG      0x08    // Own Address (W)
#define I2C_SLAVE_TXDATA_REG    0x0C    // Transmit Data (W)
#define I2C_SLAVE_RXDATA_REG    0x10    // Receive Data (R)

// STAT Register Bits
#define I2C_SLAVE_STAT_ADDR_MATCH   (1 << 0)    // Address matched
#define I2C_SLAVE_STAT_ACK_SENT     (1 << 1)    // ACK sent
#define I2C_SLAVE_STAT_DATA_VALID   (1 << 2)    // New data received

//==============================================================================
// Register Access Macros
//==============================================================================
#define I2C_MASTER_WRITE_REG(base, offset, value) \
    (*((volatile uint32_t *)((base) + (offset))) = (value))

#define I2C_MASTER_READ_REG(base, offset) \
    (*((volatile uint32_t *)((base) + (offset))))

#define I2C_SLAVE_WRITE_REG(base, offset, value) \
    (*((volatile uint32_t *)((base) + (offset))) = (value))

#define I2C_SLAVE_READ_REG(base, offset) \
    (*((volatile uint32_t *)((base) + (offset))))

//==============================================================================
// Default Values
//==============================================================================
#define I2C_DEFAULT_SLAVE_ADDR  0x55    // Default slave address (7-bit)

#endif // I2C_REGS_H

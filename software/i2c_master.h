/**
 * @file i2c_master.h
 * @brief I2C Master Driver for MicroBlaze System
 *
 * Register Map (AXI4-Lite):
 *   0x00: Control Register (Write triggers I2C transaction)
 *         [15:8]  tx_data  - Data to transmit
 *         [7:1]   slave_addr - 7-bit slave address
 *         [0]     rw_bit   - 0=Write, 1=Read
 *
 *   0x04: Status Register (Read-only)
 *         [2]     ack_error - NACK or error occurred
 *         [1]     done     - Transaction completed
 *         [0]     busy     - Transaction in progress
 *
 *   0x08: RX Data Register (Read-only)
 *         [7:0]   rx_data  - Received data
 */

#ifndef I2C_MASTER_H
#define I2C_MASTER_H

#include "xil_io.h"
#include "xparameters.h"

//==============================================================================
// I2C Master Base Address (Update this with actual address from Address Editor)
//==============================================================================
#ifndef XPAR_I2C_MASTER_0_S00_AXI_BASEADDR
#define I2C_MASTER_BASEADDR     0x40000000  // Default - CHECK Address Editor!
#else
#define I2C_MASTER_BASEADDR     XPAR_I2C_MASTER_0_S00_AXI_BASEADDR
#endif

//==============================================================================
// Register Offsets
//==============================================================================
#define I2C_CTRL_REG_OFFSET     0x00
#define I2C_STATUS_REG_OFFSET   0x04
#define I2C_RXDATA_REG_OFFSET   0x08

//==============================================================================
// Status Register Bits
//==============================================================================
#define I2C_STATUS_BUSY         (1 << 0)
#define I2C_STATUS_DONE         (1 << 1)
#define I2C_STATUS_ACK_ERROR    (1 << 2)

//==============================================================================
// I2C Slave Addresses
//==============================================================================
#define I2C_SLAVE_LED_ADDR      0x55    // LED Slave
#define I2C_SLAVE_FND_ADDR      0x56    // 7-Segment Display Slave
#define I2C_SLAVE_SWITCH_ADDR   0x57    // Switch Slave

//==============================================================================
// I2C Transaction Types
//==============================================================================
#define I2C_WRITE               0
#define I2C_READ                1

//==============================================================================
// Timeout Configuration
//==============================================================================
#define I2C_TIMEOUT_CYCLES      100000  // Timeout for busy wait

//==============================================================================
// Function Prototypes
//==============================================================================

/**
 * @brief Write one byte to I2C slave
 * @param slave_addr 7-bit slave address
 * @param data Data byte to write
 * @return 0 on success, -1 on timeout, -2 on ACK error
 */
int i2c_write_byte(u8 slave_addr, u8 data);

/**
 * @brief Read one byte from I2C slave
 * @param slave_addr 7-bit slave address
 * @param data Pointer to store read data
 * @return 0 on success, -1 on timeout, -2 on ACK error
 */
int i2c_read_byte(u8 slave_addr, u8 *data);

/**
 * @brief Wait for I2C transaction to complete
 * @return 0 on success, -1 on timeout, -2 on ACK error
 */
int i2c_wait_done(void);

/**
 * @brief Initialize I2C master (placeholder - no initialization needed)
 */
void i2c_init(void);

/**
 * @brief Display I2C transaction status
 * @param status Status value from i2c_write_byte or i2c_read_byte
 */
void i2c_print_status(int status);

#endif // I2C_MASTER_H

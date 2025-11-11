`timescale 1ns / 1ps

//==============================================================================
// I2C Package - Common Parameters and Definitions
//==============================================================================
package i2c_pkg;

    // System Parameters
    parameter int CLK_FREQ      = 100_000_000;  // 100 MHz system clock
    parameter int SCL_FREQ      = 100_000;      // 100 kHz I2C SCL
    parameter int CLK_PER_BIT   = CLK_FREQ / (SCL_FREQ * 4);  // 250 cycles per quarter bit
    parameter int HALF_PERIOD   = CLK_PER_BIT * 2;            // 500 cycles for half SCL period

    // I2C Protocol Parameters
    parameter logic [6:0] SLAVE_ADDR = 7'b1010101;  // 0x55
    parameter int DATA_WIDTH = 8;

    // I2C Commands
    parameter logic I2C_WRITE = 1'b0;
    parameter logic I2C_READ  = 1'b1;

    // State Encoding (for debug visibility)
    typedef enum logic [4:0] {
        IDLE       = 5'd0,
        // Start Condition
        START_1    = 5'd1,   // SDA high, SCL high (setup)
        START_2    = 5'd2,   // SDA low, SCL high (start condition)
        START_3    = 5'd3,   // SDA low, SCL low (prepare for data)

        // Address Phase (7-bit addr + 1-bit R/W)
        ADDR_BIT   = 5'd4,   // Transmit address bits
        ADDR_ACK   = 5'd5,   // Wait for address ACK from slave

        // Data Phase
        DATA_BIT   = 5'd6,   // Transmit/Receive data bits
        DATA_ACK   = 5'd7,   // ACK for data byte

        // Master ACK (for read operations)
        MACK       = 5'd8,   // Master sends ACK/NACK

        // Stop Condition
        STOP_1     = 5'd9,   // SDA low, SCL low
        STOP_2     = 5'd10,  // SDA low, SCL high
        STOP_3     = 5'd11,  // SDA high, SCL high (stop condition)

        // Error/Done
        DONE       = 5'd12,
        ERROR      = 5'd13
    } i2c_state_t;

    // SCL Clock States (sub-states for timing)
    typedef enum logic [1:0] {
        SCL_LOW_1  = 2'd0,   // First half of SCL low
        SCL_LOW_2  = 2'd1,   // Second half of SCL low
        SCL_HIGH_1 = 2'd2,   // First half of SCL high
        SCL_HIGH_2 = 2'd3    // Second half of SCL high
    } scl_phase_t;

endpackage : i2c_pkg

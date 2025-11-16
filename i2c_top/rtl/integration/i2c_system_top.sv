`timescale 1ns / 1ps

//==============================================================================
// I2C Multi-Slave System Top
//==============================================================================
// Integrates I2C Master with three slaves on a shared I2C bus
//  - LED Slave (0x55)
//  - FND Slave (0x56)
//  - Switch Slave (0x57)
//
// This module demonstrates the core I2C multi-device bus concept
//==============================================================================

module i2c_system_top (
    // System
    input  logic        clk,              // 100 MHz system clock
    input  logic        rst_n,            // Active-low reset

    // Master Control Interface
    input  logic        start,            // Start I2C transaction
    input  logic        rw_bit,           // 0=Write, 1=Read
    input  logic [6:0]  slave_addr,       // 7-bit slave address
    input  logic [7:0]  tx_data,          // Data to transmit
    output logic [7:0]  rx_data,          // Received data
    output logic        busy,             // Transaction in progress
    output logic        done,             // Transaction completed
    output logic        ack_error,        // NACK or error

    // External I/O
    input  logic [7:0]  SW,               // Switch input
    output logic [7:0]  LED,              // LED output
    output logic [6:0]  SEG,              // 7-segment cathodes
    output logic [3:0]  AN,               // 7-segment anodes

    // Debug (optional)
    output logic        debug_addr_match_led,
    output logic        debug_addr_match_fnd,
    output logic        debug_addr_match_sw,
    output logic [4:0]  debug_master_state,
    output logic [3:0]  debug_led_state,
    output logic [3:0]  debug_fnd_state,
    output logic [3:0]  debug_sw_state
);

    //==========================================================================
    // Internal I2C Bus (tri-state with pull-ups)
    //==========================================================================
    wire sda;   // I2C data line (shared by master + 3 slaves)
    wire scl;   // I2C clock line (driven by master)

    // I2C Pull-up resistors (required for open-drain operation)
    // In simulation: weak1 pull-up, in hardware: physical 4.7k resistors
    assign (weak1, weak0) sda = 1'b1;
    assign (weak1, weak0) scl = 1'b1;

    //==========================================================================
    // I2C Master Instance
    //==========================================================================
    i2c_master master (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .sda(sda),
        .scl(scl),
        .debug_busy(),
        .debug_ack(),
        .debug_state(debug_master_state),
        .debug_scl(),
        .debug_sda_out(),
        .debug_sda_oe()
    );

    //==========================================================================
    // LED Slave (Address: 0x55)
    //==========================================================================
    i2c_led_slave led_slave (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .LED(LED),
        .debug_addr_match(debug_addr_match_led),
        .debug_state(debug_led_state)
    );

    //==========================================================================
    // FND Slave (Address: 0x56)
    //==========================================================================
    i2c_fnd_slave fnd_slave (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SEG(SEG),
        .AN(AN),
        .debug_addr_match(debug_addr_match_fnd),
        .debug_state(debug_fnd_state)
    );

    //==========================================================================
    // Switch Slave (Address: 0x57)
    //==========================================================================
    i2c_switch_slave switch_slave (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SW(SW),
        .debug_addr_match(debug_addr_match_sw),
        .debug_state(debug_sw_state)
    );

endmodule

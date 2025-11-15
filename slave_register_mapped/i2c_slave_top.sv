`timescale 1ns / 1ps

//==============================================================================
// I2C Slave Top Module
//==============================================================================
// Integrates I2C protocol engine and register map
// For Basys3 FPGA board
//==============================================================================

module i2c_slave_top (
    // System
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset (BTN)

    // I2C Bus
    input  logic       scl,              // I2C clock from master
    inout  logic       sda,              // I2C data (bidirectional)

    // External I/O
    input  logic [15:0] SW,              // Switches
    output logic [15:0] LED,             // LEDs
    output logic [6:0]  SEG,             // 7-segment cathodes
    output logic [3:0]  AN,              // 7-segment anodes

    // Debug (optional - map to LEDs if needed)
    output logic       debug_addr_match,
    output logic [3:0] debug_state
);

    //==========================================================================
    // Internal Signals - Protocol <-> Register Map
    //==========================================================================
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wen;
    logic       reg_ren;
    logic [7:0] reg_rdata;

    //==========================================================================
    // I2C Slave Address Configuration
    //==========================================================================
    localparam logic [6:0] SLAVE_ADDR = 7'h55;

    //==========================================================================
    // I2C Protocol Engine
    //==========================================================================
    i2c_slave_protocol protocol (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(SLAVE_ADDR),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wen(reg_wen),
        .reg_ren(reg_ren),
        .reg_rdata(reg_rdata),
        .scl(scl),
        .sda(sda),
        .debug_addr_match(debug_addr_match),
        .debug_state(debug_state)
    );

    //==========================================================================
    // Register Map (LED/FND Control)
    //==========================================================================
    slave_register_map registers (
        .clk(clk),
        .rst_n(rst_n),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wen(reg_wen),
        .reg_ren(reg_ren),
        .reg_rdata(reg_rdata),
        .SW(SW),
        .LED(LED),
        .SEG(SEG),
        .AN(AN)
    );

endmodule

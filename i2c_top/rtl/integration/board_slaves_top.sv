`timescale 1ns / 1ps

//==============================================================================
// Board #2: I2C Slaves Top Module (3 Slaves)
//==============================================================================
// For multi-board configuration: This board has 3 I2C slaves
//  - LED Slave (0x55)
//  - FND Slave (0x56)
//  - Switch Slave (0x57)
//
// Connection via PMOD:
//  - JA1: SCL (input from Master board)
//  - JA2: SDA (bidirectional)
//  - GND: Common ground with Master board
//
// Pull-up resistors (4.7kΩ) required on SCL and SDA
//==============================================================================

module board_slaves_top (
    // System
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset (BTN)

    // I2C Bus (PMOD JA)
    input  logic       scl,              // I2C clock (from master board)
    inout  logic       sda,              // I2C data (bidirectional)

    // External I/O
    input  logic [15:0] SW,              // Switches (only SW[7:0] used)
    output logic [15:0] LED,             // LEDs (only LED[7:0] used by slave)
    output logic [6:0]  SEG,             // 7-segment cathodes
    output logic [3:0]  AN               // 7-segment anodes
);

    //==========================================================================
    // Internal Wires
    //==========================================================================
    logic [7:0] led_out;

    // Debug signals from slaves
    logic       debug_addr_match_led;
    logic [3:0] debug_state_led;
    logic       debug_addr_match_fnd;
    logic [3:0] debug_state_fnd;
    logic       debug_addr_match_sw;
    logic [3:0] debug_state_sw;

    //==========================================================================
    // LED Outputs
    //==========================================================================
    // LED[7:0]: LED slave output
    assign LED[7:0]  = led_out;

    // LED[15:8]: Debug status (optional)
    assign LED[8]    = debug_addr_match_led;  // LED slave addressed
    assign LED[9]    = debug_addr_match_fnd;  // FND slave addressed
    assign LED[10]   = debug_addr_match_sw;   // Switch slave addressed
    assign LED[11]   = (debug_state_led != 4'd0);  // LED slave active
    assign LED[12]   = (debug_state_fnd != 4'd0);  // FND slave active
    assign LED[13]   = (debug_state_sw != 4'd0);   // Switch slave active
    assign LED[15:14] = 2'b00;  // Unused

    //==========================================================================
    // LED Slave (Address: 0x55)
    //==========================================================================
    i2c_led_slave led_slave (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .LED(led_out),
        .debug_addr_match(debug_addr_match_led),
        .debug_state(debug_state_led)
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
        .debug_state(debug_state_fnd)
    );

    //==========================================================================
    // Switch Slave (Address: 0x57)
    //==========================================================================
    i2c_switch_slave switch_slave (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SW(SW[7:0]),
        .debug_addr_match(debug_addr_match_sw),
        .debug_state(debug_state_sw)
    );

endmodule

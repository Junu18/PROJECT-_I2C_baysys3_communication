//==============================================================================
// I2C Slave Board Module
// Simulates a Basys3 board with 3 I2C Slaves
// For board-to-board communication testing
//==============================================================================

module i2c_slave_board (
    input  logic        clk,
    input  logic        rst,

    // Switch inputs (for Switch Slave)
    input  logic [7:0]  SW,

    // LED outputs (from LED Slave)
    output logic [7:0]  LED,

    // 7-Segment Display (from FND Slave)
    output logic [6:0]  SEG,
    output logic [3:0]  AN,

    // I2C Bus (PMOD pins JA1, JA2)
    inout  wire         sda,
    inout  wire         scl
);

    //==========================================================================
    // Slave 1: LED Slave (0x55)
    //==========================================================================
    i2c_led_slave u_led_slave (
        .clk   (clk),
        .rst   (rst),
        .scl   (scl),
        .sda   (sda),
        .LED   (LED),
        // Debug ports (not connected)
        .debug_addr_match (),
        .debug_state      ()
    );

    //==========================================================================
    // Slave 2: 7-Segment Display Slave (0x56)
    //==========================================================================
    i2c_fnd_slave u_fnd_slave (
        .clk   (clk),
        .rst   (rst),
        .scl   (scl),
        .sda   (sda),
        .SEG   (SEG),
        .AN    (AN),
        // Debug ports (not connected)
        .debug_addr_match (),
        .debug_state      ()
    );

    //==========================================================================
    // Slave 3: Switch Slave (0x57)
    //==========================================================================
    i2c_switch_slave u_switch_slave (
        .clk   (clk),
        .rst   (rst),
        .scl   (scl),
        .sda   (sda),
        .SW    (SW),
        // Debug ports (not connected)
        .debug_addr_match (),
        .debug_state      ()
    );

endmodule

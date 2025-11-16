//==============================================================================
// I2C Master Board Module
// Simulates a Basys3 board with only the I2C Master
// For board-to-board communication testing
//==============================================================================

module i2c_master_board (
    input  logic        clk,
    input  logic        rst_n,

    // User Interface (switches, buttons)
    input  logic        start,
    input  logic [6:0]  slave_addr,
    input  logic        rw_bit,
    input  logic [7:0]  tx_data,

    // Status LEDs
    output logic        busy,
    output logic        done,
    output logic        ack_error,
    output logic [7:0]  rx_data,

    // I2C Bus (PMOD pins JA1, JA2)
    inout  tri1         sda,
    inout  tri1         scl
);

    //==========================================================================
    // I2C Master Instance
    //==========================================================================
    i2c_master u_master (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .slave_addr (slave_addr),
        .rw_bit     (rw_bit),
        .tx_data    (tx_data),
        .busy       (busy),
        .done       (done),
        .ack_error  (ack_error),
        .rx_data    (rx_data),
        .sda        (sda),
        .scl        (scl),
        // Debug ports (not connected)
        .debug_busy    (),
        .debug_ack     (),
        .debug_state   (),
        .debug_scl     (),
        .debug_sda_out (),
        .debug_sda_oe  ()
    );

endmodule

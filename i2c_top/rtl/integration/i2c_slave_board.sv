//==============================================================================
// I2C Slave Board Module
// Simulates a Basys3 board with 3 I2C Slaves
// For board-to-board communication testing
//==============================================================================

module i2c_slave_board (
    input  logic        clk,
    input  logic        rst_n,

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
    // I2C Bus signals
    //==========================================================================
    logic sda_in;

    // LED Slave signals
    logic sda_out_led, sda_oe_led;

    // FND Slave signals
    logic sda_out_fnd, sda_oe_fnd;

    // Switch Slave signals
    logic sda_out_sw, sda_oe_sw;

    //==========================================================================
    // Slave 1: LED Slave (0x55)
    //==========================================================================
    i2c_led_slave u_led_slave (
        .clk     (clk),
        .rst_n   (rst_n),
        .sda_in  (sda_in),
        .sda_out (sda_out_led),
        .sda_oe  (sda_oe_led),
        .scl     (scl),
        .LED     (LED)
    );

    //==========================================================================
    // Slave 2: 7-Segment Display Slave (0x56)
    //==========================================================================
    i2c_fnd_slave u_fnd_slave (
        .clk     (clk),
        .rst_n   (rst_n),
        .sda_in  (sda_in),
        .sda_out (sda_out_fnd),
        .sda_oe  (sda_oe_fnd),
        .scl     (scl),
        .SEG     (SEG),
        .AN      (AN)
    );

    //==========================================================================
    // Slave 3: Switch Slave (0x57)
    //==========================================================================
    i2c_switch_slave u_switch_slave (
        .clk     (clk),
        .rst_n   (rst_n),
        .sda_in  (sda_in),
        .sda_out (sda_out_sw),
        .sda_oe  (sda_oe_sw),
        .scl     (scl),
        .SW      (SW)
    );

    //==========================================================================
    // Tri-state I2C Bus (PMOD connection)
    // Wired-AND: Any slave can pull SDA low
    //==========================================================================
    logic sda_out_combined, sda_oe_combined;

    assign sda_oe_combined  = sda_oe_led | sda_oe_fnd | sda_oe_sw;
    assign sda_out_combined = (sda_oe_led ? sda_out_led : 1'b1) &
                              (sda_oe_fnd ? sda_out_fnd : 1'b1) &
                              (sda_oe_sw  ? sda_out_sw  : 1'b1);

    assign sda    = sda_oe_combined ? sda_out_combined : 1'bz;
    assign sda_in = sda;

endmodule

`timescale 1ns / 1ps

//==============================================================================
// I2C Single Board Top Module
//==============================================================================
// Purpose:
//  - Integrates both I2C Master and Slave on a single Basys3 board
//  - Internal loopback mode for testing
//  - Optional external PMOD connection for monitoring
//==============================================================================

module i2c_single_board_top (
    // Clock and Reset
    input  logic        clk,              // 100 MHz system clock
    input  logic        rst_n,            // Active-low reset (BTNC)

    // Control Buttons
    input  logic        btn_start,        // Start I2C transaction (BTNU)
    input  logic        btn_mode,         // Display mode toggle (BTNL)
    input  logic        btn_loopback,     // Loopback enable (BTNR)

    // Configuration Switches
    input  logic [7:0]  sw_tx_data,       // SW[7:0] - Master TX data
    input  logic        sw_rw,            // SW[8] - Read/Write bit
    input  logic [6:0]  sw_slave_addr,    // SW[15:9] - Slave address

    // LED Outputs
    output logic [7:0]  led_data,         // LED[7:0] - Data display (muxed)
    output logic        led_master_busy,  // LED8 - Master busy
    output logic        led_master_done,  // LED9 - Master done
    output logic        led_master_ack,   // LED10 - Master ACK
    output logic        led_slave_match,  // LED11 - Slave address match
    output logic        led_slave_valid,  // LED12 - Slave data valid
    output logic        led_scl,          // LED13 - SCL monitor
    output logic        led_sda,          // LED14 - SDA monitor
    output logic        led_loopback,     // LED15 - Loopback status

    // External PMOD (optional monitoring)
    inout  logic        pmod_scl,         // JB1 - SCL output for monitoring
    inout  logic        pmod_sda          // JB2 - SDA output for monitoring
);

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam logic [6:0] DEFAULT_SLAVE_ADDR = 7'b1010101;  // 0x55

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Button debouncing
    logic start_debounced;
    logic mode_debounced;
    logic loopback_debounced;
    logic display_mode;  // 0=Master TX, 1=Slave RX

    // I2C Bus (internal)
    wire  scl_internal;
    wire  sda_internal;

    // Master signals
    logic [7:0] master_tx_data;
    logic [7:0] master_rx_data;
    logic       master_busy;
    logic       master_done;
    logic       master_ack_error;
    logic       master_debug_busy;
    logic       master_debug_ack;
    logic [4:0] master_debug_state;
    logic       master_debug_scl;
    logic       master_debug_sda_out;
    logic       master_debug_sda_oe;

    // Slave signals
    logic [6:0] slave_addr;
    logic [7:0] slave_tx_data;
    logic [7:0] slave_rx_data;
    logic       slave_data_valid;
    logic       slave_debug_addr_match;
    logic       slave_debug_ack_sent;
    logic [1:0] slave_debug_state;
    logic       slave_debug_sda_out;
    logic       slave_debug_sda_oe;

    // Loopback control
    logic loopback_enable;

    //==========================================================================
    // Button Debouncing (simple)
    //==========================================================================
    logic [19:0] debounce_counter_start;
    logic [19:0] debounce_counter_mode;
    logic        start_prev, mode_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_counter_start <= 20'd0;
            debounce_counter_mode  <= 20'd0;
            start_debounced        <= 1'b0;
            mode_debounced         <= 1'b0;
            start_prev             <= 1'b0;
            mode_prev              <= 1'b0;
            display_mode           <= 1'b0;
            loopback_enable        <= 1'b1;  // Default: loopback enabled
        end else begin
            start_prev <= btn_start;
            mode_prev  <= btn_mode;

            // Start button - edge detection
            if (btn_start && !start_prev) begin
                if (debounce_counter_start == 20'd999_999) begin  // ~10ms at 100MHz
                    start_debounced <= 1'b1;
                    debounce_counter_start <= 20'd0;
                end else begin
                    debounce_counter_start <= debounce_counter_start + 1;
                end
            end else begin
                start_debounced <= 1'b0;
                debounce_counter_start <= 20'd0;
            end

            // Mode button - toggle display mode
            if (btn_mode && !mode_prev) begin
                if (debounce_counter_mode == 20'd999_999) begin
                    display_mode <= ~display_mode;
                    debounce_counter_mode <= 20'd0;
                end else begin
                    debounce_counter_mode <= debounce_counter_mode + 1;
                end
            end else if (!btn_mode) begin
                debounce_counter_mode <= 20'd0;
            end

            // Loopback button (toggle)
            if (btn_loopback && !start_prev) begin  // Reuse start_prev for simplicity
                loopback_enable <= ~loopback_enable;
            end
        end
    end

    //==========================================================================
    // Master Configuration
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            master_tx_data <= 8'h00;
        end else begin
            master_tx_data <= sw_tx_data;
        end
    end

    // Slave TX data (for read operations) - use inverted master TX data for testing
    assign slave_tx_data = ~sw_tx_data;

    // Slave address configuration
    assign slave_addr = (sw_slave_addr == 7'd0) ? DEFAULT_SLAVE_ADDR : sw_slave_addr;

    //==========================================================================
    // I2C Master Instance
    //==========================================================================
    i2c_master master (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start_debounced),
        .rw_bit         (sw_rw),
        .slave_addr     (slave_addr),
        .tx_data        (master_tx_data),
        .rx_data        (master_rx_data),
        .busy           (master_busy),
        .done           (master_done),
        .ack_error      (master_ack_error),
        .sda            (sda_internal),
        .scl            (scl_internal),
        .debug_busy     (master_debug_busy),
        .debug_ack      (master_debug_ack),
        .debug_state    (master_debug_state),
        .debug_scl      (master_debug_scl),
        .debug_sda_out  (master_debug_sda_out),
        .debug_sda_oe   (master_debug_sda_oe)
    );

    //==========================================================================
    // I2C Slave Instance
    //==========================================================================
    i2c_slave slave (
        .clk                (clk),
        .rst_n              (rst_n),
        .slave_addr         (slave_addr),
        .tx_data            (slave_tx_data),
        .rx_data            (slave_rx_data),
        .data_valid         (slave_data_valid),
        .scl                (scl_internal),
        .sda                (sda_internal),
        .debug_addr_match   (slave_debug_addr_match),
        .debug_ack_sent     (slave_debug_ack_sent),
        .debug_state        (slave_debug_state),
        .debug_sda_out      (slave_debug_sda_out),
        .debug_sda_oe       (slave_debug_sda_oe)
    );

    //==========================================================================
    // External PMOD Connection (for monitoring)
    //==========================================================================
    assign pmod_scl = loopback_enable ? scl_internal : 1'bz;
    assign pmod_sda = loopback_enable ? sda_internal : 1'bz;

    //==========================================================================
    // LED Data Display (Multiplexed)
    //==========================================================================
    always_comb begin
        if (display_mode == 1'b0) begin
            // Display Master TX data
            led_data = master_tx_data;
        end else begin
            // Display Slave RX data
            led_data = slave_rx_data;
        end
    end

    //==========================================================================
    // Status LED Assignments
    //==========================================================================
    assign led_master_busy  = master_busy;
    assign led_master_done  = master_done;
    assign led_master_ack   = master_debug_ack;
    assign led_slave_match  = slave_debug_addr_match;
    assign led_slave_valid  = slave_data_valid;
    assign led_scl          = scl_internal;
    assign led_sda          = sda_internal;
    assign led_loopback     = loopback_enable;

endmodule : i2c_single_board_top

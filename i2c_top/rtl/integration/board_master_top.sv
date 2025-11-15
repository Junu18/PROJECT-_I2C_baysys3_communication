`timescale 1ns / 1ps

//==============================================================================
// Board #1: I2C Master Top Module (Reference Design)
//==============================================================================
// NOTE: In actual implementation, this board will use:
//       - MicroBlaze soft processor
//       - Vivado AXI I2C Master IP (created from i2c_master.sv)
//       - Firmware to control I2C transactions
//
// This module is a REFERENCE DESIGN for standalone testing only.
// For real board-to-board communication, use Vivado Block Design with:
//   - MicroBlaze
//   - AXI Interconnect
//   - Custom I2C Master AXI IP
//==============================================================================

module board_master_top (
    // System
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset (BTN)

    // I2C Bus (PMOD JA - outputs to slave board)
    output logic       scl,              // I2C clock (to slave board)
    inout  logic       sda,              // I2C data (bidirectional)

    // Control Interface (from buttons/switches for testing)
    input  logic       btn_start,        // Start transaction
    input  logic [15:0] SW,              // SW[15]: R/W, SW[14:8]: Addr, SW[7:0]: Data
    output logic [15:0] LED              // LED[7:0]: RX data, LED[8]: busy, LED[9]: done
);

    //==========================================================================
    // Control Signals
    //==========================================================================
    logic        start;
    logic        rw_bit;
    logic [6:0]  slave_addr;
    logic [7:0]  tx_data;
    logic [7:0]  rx_data;
    logic        busy;
    logic        done;
    logic        ack_error;

    // Button synchronization
    logic [2:0]  btn_sync;
    logic        btn_prev;
    logic        btn_pulse;

    //==========================================================================
    // Button Edge Detection (for start signal)
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync <= 3'b000;
            btn_prev <= 1'b0;
        end else begin
            btn_sync <= {btn_sync[1:0], btn_start};
            btn_prev <= btn_sync[2];
        end
    end

    assign btn_pulse = btn_sync[2] & ~btn_prev;
    assign start = btn_pulse;

    //==========================================================================
    // Control from Switches
    //==========================================================================
    assign rw_bit     = SW[15];
    assign slave_addr = SW[14:8];
    assign tx_data    = SW[7:0];

    //==========================================================================
    // LED Status Outputs
    //==========================================================================
    assign LED[7:0]  = rx_data;
    assign LED[8]    = busy;
    assign LED[9]    = done;
    assign LED[10]   = ack_error;
    assign LED[15:11] = 5'b00000;

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
        .debug_state(),
        .debug_scl(),
        .debug_sda_out(),
        .debug_sda_oe()
    );

endmodule

//==============================================================================
// ACTUAL IMPLEMENTATION GUIDE (for MicroBlaze system):
//==============================================================================
// 1. Create Vivado Block Design
// 2. Add MicroBlaze processor
// 3. Package i2c_master.sv as AXI IP using Vivado S00_AXI template
// 4. Add custom I2C Master IP to block design
// 5. Connect I2C SDA/SCL to PMOD JA pins
// 6. Write firmware (C code) to control I2C transactions
//
// Firmware example:
//   i2c_write(0x55, 0xFF);  // LED ON
//   i2c_write(0x56, 0x05);  // FND shows '5'
//   uint8_t sw = i2c_read(0x57);  // Read switch
//==============================================================================

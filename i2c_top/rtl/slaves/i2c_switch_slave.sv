`timescale 1ns / 1ps

//==============================================================================
// I2C Switch Slave (Address: 0x57)
//==============================================================================
// Simple I2C slave that reads switch values
// Protocol: [START][0xAE][STOP] → [START][0xAF][DATA][NACK][STOP]
//           where 0xAE = (0x57 << 1) | WRITE (address setup)
//           and   0xAF = (0x57 << 1) | READ  (data read)
//
// Features:
//  - Single-byte read-only protocol
//  - Returns SW[7:0] value
//  - No register addressing needed
//==============================================================================

module i2c_switch_slave (
    // System
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset

    // I2C Bus
    input  logic       scl,              // I2C clock from master
    inout  logic       sda,              // I2C data (bidirectional)

    // Switch Input
    input  logic [7:0] SW,               // Switch input [7:0]

    // Debug (optional)
    output logic       debug_addr_match,
    output logic [3:0] debug_state
);

    //==========================================================================
    // Configuration
    //==========================================================================
    localparam logic [6:0] SLAVE_ADDR = 7'h57;

    //==========================================================================
    // FSM States
    //==========================================================================
    typedef enum logic [3:0] {
        IDLE         = 4'd0,    // Wait for START
        START        = 4'd1,    // START detected
        RX_DEV_ADDR  = 4'd2,    // Receive device address (7-bit + R/W)
        DEV_ADDR_ACK = 4'd3,    // Send ACK for device address
        TX_DATA      = 4'd4,    // Transmit read data
        TX_DATA_ACK  = 4'd5,    // Wait for master ACK/NACK
        WAIT_STOP    = 4'd6,    // Wait for STOP
        ERROR        = 4'd7
    } state_t;

    //==========================================================================
    // Internal Signals
    //==========================================================================
    state_t state, state_next;

    // SCL/SDA synchronization
    logic [2:0] scl_sync;
    logic [2:0] sda_sync;
    logic       scl_rising_edge;
    logic       scl_falling_edge;
    logic       scl_high;
    logic       sda_in;
    logic       sda_prev;

    // START/STOP detection
    logic       start_detected;
    logic       stop_detected;

    // Data registers
    logic [7:0] dev_addr_reg, dev_addr_next;
    logic [7:0] tx_shift, tx_shift_next;
    logic [2:0] bit_count, bit_count_next;
    logic [7:0] received_addr;  // Address matching temp variable

    // Control flags
    logic       addr_match, addr_match_next;
    logic       rw_bit;

    // SDA control
    logic       sda_out, sda_out_next;
    logic       sda_oe, sda_oe_next;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;
    assign rw_bit = dev_addr_reg[0];

    assign debug_addr_match = addr_match;
    assign debug_state = state;

    //==========================================================================
    // SCL/SDA Synchronization
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
            sda_prev <= 1'b1;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
            sda_prev <= sda_in;
        end
    end

    assign scl_rising_edge  = (scl_sync[2:1] == 2'b01);
    assign scl_falling_edge = (scl_sync[2:1] == 2'b10);
    assign scl_high         = scl_sync[2];
    assign sda_in           = sda_sync[2];

    // START: SDA falls while SCL high
    assign start_detected = (sda_prev & ~sda_in) & scl_high;

    // STOP: SDA rises while SCL high
    assign stop_detected = (~sda_prev & sda_in) & scl_high;

    //==========================================================================
    // Sequential Logic
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            dev_addr_reg <= 8'd0;
            tx_shift     <= 8'd0;
            bit_count    <= 3'd0;
            sda_out      <= 1'b1;
            sda_oe       <= 1'b0;
            addr_match   <= 1'b0;
        end else begin
            state        <= state_next;
            dev_addr_reg <= dev_addr_next;
            tx_shift     <= tx_shift_next;
            bit_count    <= bit_count_next;
            sda_out      <= sda_out_next;
            sda_oe       <= sda_oe_next;
            addr_match   <= addr_match_next;
        end
    end

    //==========================================================================
    // Combinational FSM
    //==========================================================================
    always_comb begin
        // Defaults
        state_next     = state;
        dev_addr_next  = dev_addr_reg;
        tx_shift_next  = tx_shift;
        bit_count_next = bit_count;
        sda_out_next   = sda_out;
        sda_oe_next    = sda_oe;
        addr_match_next = addr_match;
        received_addr  = 8'h00;  // Default to avoid latch

        // Global STOP detection
        if (stop_detected && (state != IDLE)) begin
            state_next      = IDLE;
            sda_oe_next     = 1'b0;
            bit_count_next  = 3'd0;
            addr_match_next = 1'b0;
        end else begin
            case (state)
                //==============================================================
                // IDLE: Wait for START
                //==============================================================
                IDLE: begin
                    sda_oe_next     = 1'b0;
                    bit_count_next  = 3'd0;
                    addr_match_next = 1'b0;

                    if (start_detected) begin
                        // Go directly to RX_DEV_ADDR to avoid missing first bit
                        state_next = RX_DEV_ADDR;
                    end
                end

                //==============================================================
                // RX_DEV_ADDR: Receive device address (7-bit + R/W)
                //==============================================================
                RX_DEV_ADDR: begin
                    sda_oe_next = 1'b0;

                    if (scl_rising_edge) begin
                        dev_addr_next = {dev_addr_reg[6:0], sda_in};
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count_next = 3'd0;
                            state_next = DEV_ADDR_ACK;

                            // Check address match (Read only for Switch)
                            // Use intermediate variable for Vivado XSim compatibility
                            received_addr = {dev_addr_reg[6:0], sda_in};
                            if (received_addr[7:1] == SLAVE_ADDR &&
                                received_addr[0] == 1'b1) begin
                                addr_match_next = 1'b1;
                            end else begin
                                addr_match_next = 1'b0;
                            end
                        end
                    end
                end

                //==============================================================
                // DEV_ADDR_ACK: Send ACK if address matched
                //==============================================================
                DEV_ADDR_ACK: begin
                    if (addr_match) begin
                        if (scl_falling_edge) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;  // ACK
                        end

                        if (scl_rising_edge) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;
                        end

                        if (scl_falling_edge && sda_oe) begin
                            // Immediately drive first data bit on SDA
                            sda_oe_next = 1'b1;
                            sda_out_next = SW[7];  // First bit (MSB)
                            tx_shift_next = {SW[6:0], 1'b0};  // Pre-shift for next bit
                            bit_count_next = 3'd1;  // Already sent first bit
                            state_next = TX_DATA;  // Go to transmit
                        end
                    end else begin
                        sda_oe_next = 1'b0;
                        state_next = WAIT_STOP;
                    end
                end

                //==============================================================
                // TX_DATA: Transmit read data
                //==============================================================
                TX_DATA: begin
                    if (scl_falling_edge) begin
                        sda_oe_next  = 1'b1;
                        sda_out_next = tx_shift[7];  // MSB first
                    end

                    if (scl_rising_edge) begin
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count_next = 3'd0;
                            state_next = TX_DATA_ACK;
                        end else begin
                            tx_shift_next = {tx_shift[6:0], 1'b0};
                        end
                    end
                end

                //==============================================================
                // TX_DATA_ACK: Wait for master ACK/NACK
                //==============================================================
                TX_DATA_ACK: begin
                    sda_oe_next = 1'b0;  // Release for master

                    if (scl_rising_edge) begin
                        // Sample master's ACK (expect NACK for single byte)
                        state_next = WAIT_STOP;
                    end
                end

                //==============================================================
                // WAIT_STOP: Wait for STOP
                //==============================================================
                WAIT_STOP: begin
                    sda_oe_next = 1'b0;
                    // Will return to IDLE on STOP detection
                end

                //==============================================================
                // ERROR
                //==============================================================
                ERROR: begin
                    sda_oe_next = 1'b0;
                    state_next = IDLE;
                end

                default: begin
                    state_next = IDLE;
                end
            endcase
        end
    end

endmodule

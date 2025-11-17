`timescale 1ns / 1ps

//==============================================================================
// I2C FND (7-Segment) Slave (Address: 0x56)
//==============================================================================
// Simple I2C slave that controls a 7-segment display
// Protocol: [START][0xAC][DIGIT][STOP]
//           where 0xAC = (0x56 << 1) | WRITE
//
// Features:
//  - Single-byte write-only protocol
//  - Displays hex digit (0x00-0x0F)
//  - Common Anode 7-segment support
//  - Single digit display (AN[0] active)
//==============================================================================

module i2c_fnd_slave (
    // System
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst,              // Active-high reset

    // I2C Bus
    input  logic       scl,              // I2C clock from master
    inout  logic       sda,              // I2C data (bidirectional)

    // 7-Segment Display Output
    output logic [6:0] SEG,              // 7-segment cathodes (active low)
    output logic [3:0] AN,               // Anodes (active low)

    // Debug (optional)
    output logic       debug_addr_match,
    output logic [3:0] debug_state
);

    //==========================================================================
    // Configuration
    //==========================================================================
    localparam logic [6:0] SLAVE_ADDR = 7'h56;

    //==========================================================================
    // FSM States
    //==========================================================================
    typedef enum logic [3:0] {
        IDLE         = 4'd0,    // Wait for START
        START        = 4'd1,    // START detected
        RX_DEV_ADDR  = 4'd2,    // Receive device address (7-bit + R/W)
        DEV_ADDR_ACK = 4'd3,    // Send ACK for device address
        RX_DATA      = 4'd4,    // Receive write data
        RX_DATA_ACK  = 4'd5,    // Send ACK for write data
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
    logic [7:0] rx_shift, rx_shift_next;
    logic [2:0] bit_count, bit_count_next;
    logic [7:0] received_addr;  // Address matching temp variable

    // Control flags
    logic       addr_match, addr_match_next;
    logic       rw_bit;

    // SDA control
    logic       sda_out, sda_out_next;
    logic       sda_oe, sda_oe_next;

    // FND register
    logic [3:0] digit_reg, digit_reg_next;
    logic [6:0] seg_pattern;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;
    assign rw_bit = dev_addr_reg[0];
    assign SEG = seg_pattern;
    assign AN = 4'b1110;  // Only AN[0] active (rightmost digit)

    assign debug_addr_match = addr_match;
    assign debug_state = state;

    //==========================================================================
    // 7-Segment Decoder (Common Anode - active low segments)
    //==========================================================================
    always_comb begin
        case (digit_reg)
            4'h0: seg_pattern = 7'b1000000;  // 0
            4'h1: seg_pattern = 7'b1111001;  // 1
            4'h2: seg_pattern = 7'b0100100;  // 2
            4'h3: seg_pattern = 7'b0110000;  // 3
            4'h4: seg_pattern = 7'b0011001;  // 4
            4'h5: seg_pattern = 7'b0010010;  // 5
            4'h6: seg_pattern = 7'b0000010;  // 6
            4'h7: seg_pattern = 7'b1111000;  // 7
            4'h8: seg_pattern = 7'b0000000;  // 8
            4'h9: seg_pattern = 7'b0010000;  // 9
            4'hA: seg_pattern = 7'b0001000;  // A
            4'hB: seg_pattern = 7'b0000011;  // b
            4'hC: seg_pattern = 7'b1000110;  // C
            4'hD: seg_pattern = 7'b0100001;  // d
            4'hE: seg_pattern = 7'b0000110;  // E
            4'hF: seg_pattern = 7'b0001110;  // F
            default: seg_pattern = 7'b1111111;  // Blank
        endcase
    end

    //==========================================================================
    // SCL/SDA Synchronization
    //==========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
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
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            dev_addr_reg <= 8'd0;
            rx_shift     <= 8'd0;
            bit_count    <= 3'd0;
            sda_out      <= 1'b1;
            sda_oe       <= 1'b0;
            addr_match   <= 1'b0;
            digit_reg    <= 4'd0;
        end else begin
            state        <= state_next;
            dev_addr_reg <= dev_addr_next;
            rx_shift     <= rx_shift_next;
            bit_count    <= bit_count_next;
            sda_out      <= sda_out_next;
            sda_oe       <= sda_oe_next;
            addr_match   <= addr_match_next;
            digit_reg    <= digit_reg_next;
        end
    end

    //==========================================================================
    // Combinational FSM
    //==========================================================================
    always_comb begin
        // Defaults
        state_next     = state;
        dev_addr_next  = dev_addr_reg;
        rx_shift_next  = rx_shift;
        bit_count_next = bit_count;
        sda_out_next   = sda_out;
        sda_oe_next    = sda_oe;
        addr_match_next = addr_match;
        digit_reg_next = digit_reg;
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

                            // Check address match (Write only for FND)
                            // Use intermediate variable for Vivado XSim compatibility
                            received_addr = {dev_addr_reg[6:0], sda_in};
                            if (received_addr[7:1] == SLAVE_ADDR &&
                                received_addr[0] == 1'b0) begin
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
                            sda_oe_next = 1'b0;
                            state_next = RX_DATA;  // Go directly to data reception
                        end
                    end else begin
                        sda_oe_next = 1'b0;
                        state_next = WAIT_STOP;
                    end
                end

                //==============================================================
                // RX_DATA: Receive write data
                //==============================================================
                RX_DATA: begin
                    sda_oe_next = 1'b0;

                    if (scl_rising_edge) begin
                        rx_shift_next = {rx_shift[6:0], sda_in};
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count_next = 3'd0;
                            state_next = RX_DATA_ACK;
                        end
                    end
                end

                //==============================================================
                // RX_DATA_ACK: Send ACK and update FND
                //==============================================================
                RX_DATA_ACK: begin
                    if (scl_falling_edge) begin
                        sda_oe_next  = 1'b1;
                        sda_out_next = 1'b0;  // ACK
                    end

                    if (scl_rising_edge) begin
                        sda_oe_next  = 1'b1;
                        sda_out_next = 1'b0;
                    end

                    if (scl_falling_edge && sda_oe) begin
                        sda_oe_next = 1'b0;
                        digit_reg_next = rx_shift[3:0];  // rx_shift already has all 8 bits, use lower 4
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

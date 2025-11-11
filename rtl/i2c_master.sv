`timescale 1ns / 1ps

//==============================================================================
// I2C Master Module
//==============================================================================
// Features:
//  - 100 MHz system clock, 100 kHz SCL
//  - 7-bit addressing (0x55 default)
//  - Single byte read/write operations
//  - Proper I2C protocol: START-ADDR-ACK-DATA-ACK-STOP
//  - Tri-state SDA control
//==============================================================================

import i2c_pkg::*;

module i2c_master (
    // Global Signals
    input  logic        clk,            // 100 MHz system clock
    input  logic        rst_n,          // Active-low reset

    // Control Interface
    input  logic        start,          // Start I2C transaction (pulse)
    input  logic        rw_bit,         // 0=Write, 1=Read
    input  logic [6:0]  slave_addr,     // 7-bit slave address
    input  logic [7:0]  tx_data,        // Data to transmit
    output logic [7:0]  rx_data,        // Received data
    output logic        busy,           // Transaction in progress
    output logic        done,           // Transaction completed (pulse)
    output logic        ack_error,      // NACK received or error

    // I2C Bus
    inout  logic        sda,            // I2C data line (tri-state)
    output logic        scl,            // I2C clock line

    // Debug Ports
    output logic        debug_busy,     // Master busy status
    output logic        debug_ack,      // ACK received
    output logic [4:0]  debug_state,    // Current FSM state
    output logic        debug_scl,      // SCL monitor
    output logic        debug_sda_out,  // SDA output value
    output logic        debug_sda_oe    // SDA output enable
);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // FSM State
    i2c_state_t state, state_next;

    // SCL Generation
    logic [9:0] clk_count, clk_count_next;      // Counter for SCL timing (0-999)
    logic       scl_reg, scl_next;              // SCL register
    scl_phase_t scl_phase, scl_phase_next;      // SCL phase within a bit

    // Data Registers
    logic [7:0] addr_rw;                        // Address + R/W bit
    logic [7:0] tx_shift, tx_shift_next;        // Transmit shift register
    logic [7:0] rx_shift, rx_shift_next;        // Receive shift register
    logic [2:0] bit_count, bit_count_next;      // Bit counter (0-7)

    // SDA Control
    logic       sda_out, sda_out_next;          // SDA output value
    logic       sda_oe, sda_oe_next;            // SDA output enable (1=drive, 0=tri-state)
    logic       sda_in;                         // SDA input value

    // Status Flags
    logic       ack_received, ack_received_next;
    logic       done_reg, done_next;
    logic       ack_error_reg, ack_error_next;

    // Control
    logic       is_read_op;                     // Current operation is read

    //==========================================================================
    // SDA Tri-State Buffer
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;
    assign sda_in = sda;

    //==========================================================================
    // SCL Output
    //==========================================================================
    assign scl = scl_reg;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign busy       = (state != IDLE) && (state != DONE);
    assign done       = done_reg;
    assign ack_error  = ack_error_reg;
    assign rx_data    = rx_shift;

    // Debug Outputs
    assign debug_busy     = busy;
    assign debug_ack      = ack_received;
    assign debug_state    = state;
    assign debug_scl      = scl_reg;
    assign debug_sda_out  = sda_out;
    assign debug_sda_oe   = sda_oe;

    //==========================================================================
    // Sequential Logic
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            clk_count      <= 10'd0;
            scl_reg        <= 1'b1;     // I2C idle = high
            scl_phase      <= SCL_LOW_1;
            tx_shift       <= 8'd0;
            rx_shift       <= 8'd0;
            bit_count      <= 3'd0;
            sda_out        <= 1'b1;     // I2C idle = high
            sda_oe         <= 1'b1;     // Drive high by default
            ack_received   <= 1'b0;
            done_reg       <= 1'b0;
            ack_error_reg  <= 1'b0;
        end else begin
            state          <= state_next;
            clk_count      <= clk_count_next;
            scl_reg        <= scl_next;
            scl_phase      <= scl_phase_next;
            tx_shift       <= tx_shift_next;
            rx_shift       <= rx_shift_next;
            bit_count      <= bit_count_next;
            sda_out        <= sda_out_next;
            sda_oe         <= sda_oe_next;
            ack_received   <= ack_received_next;
            done_reg       <= done_next;
            ack_error_reg  <= ack_error_next;
        end
    end

    //==========================================================================
    // Address + R/W Byte
    //==========================================================================
    assign addr_rw = {slave_addr, rw_bit};

    //==========================================================================
    // Combinational FSM Logic
    //==========================================================================
    always_comb begin
        // Default: Hold current values
        state_next        = state;
        clk_count_next    = clk_count;
        scl_next          = scl_reg;
        scl_phase_next    = scl_phase;
        tx_shift_next     = tx_shift;
        rx_shift_next     = rx_shift;
        bit_count_next    = bit_count;
        sda_out_next      = sda_out;
        sda_oe_next       = sda_oe;
        ack_received_next = ack_received;
        done_next         = 1'b0;       // Pulse signal
        ack_error_next    = ack_error_reg;

        case (state)
            //==================================================================
            // IDLE: Wait for start command
            //==================================================================
            IDLE: begin
                scl_next       = 1'b1;
                sda_out_next   = 1'b1;
                sda_oe_next    = 1'b1;
                clk_count_next = 10'd0;
                ack_error_next = 1'b0;
                done_next      = 1'b0;

                if (start) begin
                    // Load data for transmission
                    tx_shift_next  = tx_data;
                    bit_count_next = 3'd0;
                    state_next     = START_1;
                end
            end

            //==================================================================
            // START Condition: SDA falls while SCL is high
            //==================================================================
            START_1: begin
                // Setup: Both SDA and SCL high
                scl_next     = 1'b1;
                sda_out_next = 1'b1;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    state_next     = START_2;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            START_2: begin
                // START: SDA falls, SCL stays high
                scl_next     = 1'b1;
                sda_out_next = 1'b0;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    state_next     = START_3;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            START_3: begin
                // Prepare for address transmission: SCL goes low
                scl_next     = 1'b0;
                sda_out_next = 1'b0;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    bit_count_next = 3'd0;
                    scl_phase_next = SCL_LOW_1;
                    state_next     = ADDR_BIT;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            //==================================================================
            // ADDR_BIT: Transmit 8 bits (7-bit addr + R/W)
            //==================================================================
            ADDR_BIT: begin
                sda_oe_next = 1'b1;  // Master drives SDA

                case (scl_phase)
                    SCL_LOW_1: begin
                        // Setup data bit on SDA while SCL is low
                        scl_next     = 1'b0;
                        sda_out_next = addr_rw[7 - bit_count];  // MSB first

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_LOW_2: begin
                        scl_next     = 1'b0;
                        sda_out_next = addr_rw[7 - bit_count];

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_1;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_1: begin
                        // SCL high: Slave samples data
                        scl_next     = 1'b1;
                        sda_out_next = addr_rw[7 - bit_count];

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_2: begin
                        scl_next     = 1'b1;
                        sda_out_next = addr_rw[7 - bit_count];

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            if (bit_count == 7) begin
                                // All 8 bits sent, go to ACK
                                bit_count_next = 3'd0;
                                scl_phase_next = SCL_LOW_1;
                                state_next     = ADDR_ACK;
                            end else begin
                                bit_count_next = bit_count + 1;
                                scl_phase_next = SCL_LOW_1;
                            end
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end
                endcase
            end

            //==================================================================
            // ADDR_ACK: Receive ACK from slave
            //==================================================================
            ADDR_ACK: begin
                case (scl_phase)
                    SCL_LOW_1: begin
                        // Release SDA for slave to drive
                        scl_next    = 1'b0;
                        sda_oe_next = 1'b0;  // Tri-state

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_LOW_2: begin
                        scl_next    = 1'b0;
                        sda_oe_next = 1'b0;

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_1;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_1: begin
                        // Sample ACK on SCL rising edge
                        scl_next    = 1'b1;
                        sda_oe_next = 1'b0;

                        if (clk_count == CLK_PER_BIT / 2) begin
                            // Sample in middle of high period
                            ack_received_next = ~sda_in;  // ACK = 0, NACK = 1
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_2: begin
                        scl_next    = 1'b1;
                        sda_oe_next = 1'b0;

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_1;

                            if (!ack_received) begin
                                // NACK received - abort
                                ack_error_next = 1'b1;
                                state_next     = STOP_1;
                            end else begin
                                // ACK received - proceed to data
                                bit_count_next = 3'd0;
                                state_next     = DATA_BIT;
                            end
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end
                endcase
            end

            //==================================================================
            // DATA_BIT: Transmit or receive 8 data bits
            //==================================================================
            DATA_BIT: begin
                case (scl_phase)
                    SCL_LOW_1: begin
                        scl_next = 1'b0;

                        if (rw_bit == I2C_WRITE) begin
                            // Write: Master drives SDA
                            sda_oe_next  = 1'b1;
                            sda_out_next = tx_shift[7 - bit_count];
                        end else begin
                            // Read: Master releases SDA
                            sda_oe_next = 1'b0;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_LOW_2: begin
                        scl_next = 1'b0;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = tx_shift[7 - bit_count];
                        end else begin
                            sda_oe_next = 1'b0;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_1;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_1: begin
                        scl_next = 1'b1;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = tx_shift[7 - bit_count];
                        end else begin
                            sda_oe_next = 1'b0;
                            // Sample data bit
                            if (clk_count == CLK_PER_BIT / 2) begin
                                rx_shift_next[7 - bit_count] = sda_in;
                            end
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_2: begin
                        scl_next = 1'b1;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = tx_shift[7 - bit_count];
                        end else begin
                            sda_oe_next = 1'b0;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;

                            if (bit_count == 7) begin
                                // All 8 bits done
                                bit_count_next = 3'd0;
                                scl_phase_next = SCL_LOW_1;
                                state_next     = DATA_ACK;
                            end else begin
                                bit_count_next = bit_count + 1;
                                scl_phase_next = SCL_LOW_1;
                            end
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end
                endcase
            end

            //==================================================================
            // DATA_ACK: Handle ACK for data byte
            //==================================================================
            DATA_ACK: begin
                case (scl_phase)
                    SCL_LOW_1: begin
                        scl_next = 1'b0;

                        if (rw_bit == I2C_WRITE) begin
                            // Write: Wait for slave ACK
                            sda_oe_next = 1'b0;
                        end else begin
                            // Read: Master sends ACK (0) or NACK (1)
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b1;  // NACK (end of read)
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_LOW_2: begin
                        scl_next = 1'b0;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next = 1'b0;
                        end else begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b1;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_1;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_1: begin
                        scl_next = 1'b1;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next = 1'b0;
                            // Sample slave ACK
                            if (clk_count == CLK_PER_BIT / 2) begin
                                ack_received_next = ~sda_in;
                            end
                        end else begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b1;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_HIGH_2;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end

                    SCL_HIGH_2: begin
                        scl_next = 1'b1;

                        if (rw_bit == I2C_WRITE) begin
                            sda_oe_next = 1'b0;
                        end else begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b1;
                        end

                        if (clk_count == CLK_PER_BIT - 1) begin
                            clk_count_next = 10'd0;
                            scl_phase_next = SCL_LOW_1;

                            // Check for error only on write
                            if ((rw_bit == I2C_WRITE) && !ack_received) begin
                                ack_error_next = 1'b1;
                            end

                            // Go to STOP
                            state_next = STOP_1;
                        end else begin
                            clk_count_next = clk_count + 1;
                        end
                    end
                endcase
            end

            //==================================================================
            // STOP Condition: SDA rises while SCL is high
            //==================================================================
            STOP_1: begin
                // Prepare: SDA low, SCL low
                scl_next     = 1'b0;
                sda_out_next = 1'b0;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    state_next     = STOP_2;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            STOP_2: begin
                // SCL goes high, SDA stays low
                scl_next     = 1'b1;
                sda_out_next = 1'b0;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    state_next     = STOP_3;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            STOP_3: begin
                // STOP: SDA rises while SCL is high
                scl_next     = 1'b1;
                sda_out_next = 1'b1;
                sda_oe_next  = 1'b1;

                if (clk_count == HALF_PERIOD - 1) begin
                    clk_count_next = 10'd0;
                    done_next      = 1'b1;  // Signal completion
                    state_next     = IDLE;
                end else begin
                    clk_count_next = clk_count + 1;
                end
            end

            //==================================================================
            // Default
            //==================================================================
            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule : i2c_master

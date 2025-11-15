`timescale 1ns / 1ps

//==============================================================================
// I2C Slave Protocol Engine
//==============================================================================
// Handles I2C protocol layer with register address support
// Features:
//  - START/STOP detection
//  - Device address matching (7-bit)
//  - Register address reception
//  - Repeated START support
//  - Write: [ADDR][REG_ADDR][DATA]
//  - Read:  [ADDR][REG_ADDR][R_START][ADDR|R][DATA]
//==============================================================================

module i2c_slave_protocol (
    // Global signals
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset

    // Configuration
    input  logic [6:0] slave_addr,       // 7-bit device address

    // Register interface
    output logic [7:0] reg_addr,         // Register address
    output logic [7:0] reg_wdata,        // Write data
    output logic       reg_wen,          // Write enable (1 clk pulse)
    output logic       reg_ren,          // Read enable (1 clk pulse)
    input  logic [7:0] reg_rdata,        // Read data

    // I2C bus
    input  logic       scl,
    inout  logic       sda,

    // Debug
    output logic       debug_addr_match,
    output logic [3:0] debug_state
);

    //==========================================================================
    // FSM States
    //==========================================================================
    typedef enum logic [3:0] {
        IDLE         = 4'd0,    // Wait for START
        START        = 4'd1,    // START detected
        RX_DEV_ADDR  = 4'd2,    // Receive device address (7-bit + R/W)
        DEV_ADDR_ACK = 4'd3,    // Send ACK for device address
        RX_REG_ADDR  = 4'd4,    // Receive register address
        REG_ADDR_ACK = 4'd5,    // Send ACK for register address
        RX_DATA      = 4'd6,    // Receive write data
        RX_DATA_ACK  = 4'd7,    // Send ACK for write data
        TX_DATA      = 4'd8,    // Transmit read data
        TX_DATA_ACK  = 4'd9,    // Receive ACK from master
        WAIT_STOP    = 4'd10,   // Wait for STOP or repeated START
        ERROR        = 4'd11
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
    logic [7:0] dev_addr_reg, dev_addr_next;     // Device addr + R/W
    logic [7:0] reg_addr_reg, reg_addr_next;     // Register address
    logic [7:0] rx_shift, rx_shift_next;         // RX shift register
    logic [7:0] tx_shift, tx_shift_next;         // TX shift register
    logic [2:0] bit_count, bit_count_next;

    // Control flags
    logic       addr_match, addr_match_next;
    logic       rw_bit;                          // 0=Write, 1=Read
    logic       reg_addr_valid, reg_addr_valid_next;

    // SDA control
    logic       sda_out, sda_out_next;
    logic       sda_oe, sda_oe_next;

    // Register interface
    logic       reg_wen_reg, reg_wen_next;
    logic       reg_ren_reg, reg_ren_next;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;
    assign rw_bit = dev_addr_reg[0];

    assign reg_addr  = reg_addr_reg;
    assign reg_wdata = rx_shift;
    assign reg_wen   = reg_wen_reg;
    assign reg_ren   = reg_ren_reg;

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
            state           <= IDLE;
            dev_addr_reg    <= 8'd0;
            reg_addr_reg    <= 8'd0;
            rx_shift        <= 8'd0;
            tx_shift        <= 8'd0;
            bit_count       <= 3'd0;
            sda_out         <= 1'b1;
            sda_oe          <= 1'b0;
            addr_match      <= 1'b0;
            reg_addr_valid  <= 1'b0;
            reg_wen_reg     <= 1'b0;
            reg_ren_reg     <= 1'b0;
        end else begin
            state           <= state_next;
            dev_addr_reg    <= dev_addr_next;
            reg_addr_reg    <= reg_addr_next;
            rx_shift        <= rx_shift_next;
            tx_shift        <= tx_shift_next;
            bit_count       <= bit_count_next;
            sda_out         <= sda_out_next;
            sda_oe          <= sda_oe_next;
            addr_match      <= addr_match_next;
            reg_addr_valid  <= reg_addr_valid_next;
            reg_wen_reg     <= reg_wen_next;
            reg_ren_reg     <= reg_ren_next;
        end
    end

    //==========================================================================
    // Combinational FSM
    //==========================================================================
    always_comb begin
        // Defaults
        state_next          = state;
        dev_addr_next       = dev_addr_reg;
        reg_addr_next       = reg_addr_reg;
        rx_shift_next       = rx_shift;
        tx_shift_next       = tx_shift;
        bit_count_next      = bit_count;
        sda_out_next        = sda_out;
        sda_oe_next         = sda_oe;
        addr_match_next     = addr_match;
        reg_addr_valid_next = reg_addr_valid;
        reg_wen_next        = 1'b0;  // Pulse
        reg_ren_next        = 1'b0;  // Pulse

        // Global STOP detection
        if (stop_detected && (state != IDLE)) begin
            state_next          = IDLE;
            sda_oe_next         = 1'b0;
            bit_count_next      = 3'd0;
            addr_match_next     = 1'b0;
            reg_addr_valid_next = 1'b0;
        end else begin
            case (state)
                //==============================================================
                // IDLE: Wait for START
                //==============================================================
                IDLE: begin
                    sda_oe_next         = 1'b0;
                    bit_count_next      = 3'd0;
                    addr_match_next     = 1'b0;
                    reg_addr_valid_next = 1'b0;

                    if (start_detected) begin
                        state_next = START;
                    end
                end

                //==============================================================
                // START: Prepare to receive device address
                //==============================================================
                START: begin
                    sda_oe_next = 1'b0;

                    if (scl_rising_edge) begin
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

                            // Check address match
                            if ({dev_addr_reg[6:0], sda_in}[7:1] == slave_addr) begin
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

                            // If Read bit and reg_addr already valid: go to TX
                            if (rw_bit == 1'b1 && reg_addr_valid) begin
                                reg_ren_next = 1'b1;  // Pulse read enable
                                tx_shift_next = reg_rdata;
                                state_next = TX_DATA;
                            end else begin
                                // Write or first access: receive register address
                                state_next = RX_REG_ADDR;
                            end
                        end
                    end else begin
                        sda_oe_next = 1'b0;
                        state_next = WAIT_STOP;
                    end
                end

                //==============================================================
                // RX_REG_ADDR: Receive register address
                //==============================================================
                RX_REG_ADDR: begin
                    sda_oe_next = 1'b0;

                    if (scl_rising_edge) begin
                        rx_shift_next = {rx_shift[6:0], sda_in};
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count_next = 3'd0;
                            reg_addr_next = {rx_shift[6:0], sda_in};
                            reg_addr_valid_next = 1'b1;
                            state_next = REG_ADDR_ACK;
                        end
                    end
                end

                //==============================================================
                // REG_ADDR_ACK: Send ACK for register address
                //==============================================================
                REG_ADDR_ACK: begin
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
                        state_next = RX_DATA;  // Expect data next
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
                // RX_DATA_ACK: Send ACK and trigger write
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
                        reg_wen_next = 1'b1;  // Trigger write!
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
                        // Sample master's ACK
                        if (sda_in == 1'b1) begin
                            // NACK - master done
                            state_next = WAIT_STOP;
                        end else begin
                            // ACK - could read more (single byte for now)
                            state_next = WAIT_STOP;
                        end
                    end
                end

                //==============================================================
                // WAIT_STOP: Wait for STOP or repeated START
                //==============================================================
                WAIT_STOP: begin
                    sda_oe_next = 1'b0;

                    if (start_detected) begin
                        // Repeated START
                        state_next = START;
                        bit_count_next = 3'd0;
                    end
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

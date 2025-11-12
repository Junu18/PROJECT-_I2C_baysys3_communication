`timescale 1ns / 1ps

//==============================================================================
// I2C Slave Module
//==============================================================================
// Features:
//  - 100 MHz system clock for edge detection
//  - 7-bit addressing (0x55 default)
//  - Single byte read/write operations
//  - Proper I2C protocol: Detects START, receives ADDR, sends ACK, handles DATA
//  - Tri-state SDA control
//==============================================================================

module i2c_slave (
    // Global Signals
    input  logic       clk,              // 100 MHz system clock
    input  logic       rst_n,            // Active-low reset

    // Slave Configuration
    input  logic [6:0] slave_addr,       // 7-bit slave address (0x55)

    // Data Interface
    input  logic [7:0] tx_data,          // Data to transmit (for read operations)
    output logic [7:0] rx_data,          // Received data (from write operations)
    output logic       data_valid,       // Pulse when new data received

    // I2C Bus
    input  logic       scl,              // I2C clock line (input)
    inout  logic       sda,              // I2C data line (tri-state)

    // Debug Ports
    output logic       debug_addr_match, // Address matched
    output logic       debug_ack_sent,   // ACK sent to master
    output logic [1:0] debug_state,      // Current FSM state (2 bits for LED)
    output logic       debug_sda_out,    // SDA output value
    output logic       debug_sda_oe      // SDA output enable
);

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam logic I2C_WRITE = 1'b0;
    localparam logic I2C_READ  = 1'b1;

    // State Encoding
    typedef enum logic [3:0] {
        IDLE       = 4'd0,   // Wait for START condition
        START      = 4'd1,   // START condition detected
        ADDR_RCV   = 4'd2,   // Receiving address byte (7-bit addr + R/W)
        ADDR_ACK   = 4'd3,   // Send ACK for address match
        DATA_RCV   = 4'd4,   // Receiving data byte (write operation)
        DATA_SEND  = 4'd5,   // Sending data byte (read operation)
        DATA_ACK   = 4'd6,   // Handle data ACK
        WAIT_STOP  = 4'd7,   // Wait for STOP or repeated START
        ERROR      = 4'd8    // Error state
    } i2c_state_t;

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // FSM State
    i2c_state_t state, state_next;

    // SCL and SDA synchronization and edge detection
    logic [2:0] scl_sync;
    logic [2:0] sda_sync;
    logic       scl_rising_edge;
    logic       scl_falling_edge;
    logic       scl_high;
    logic       scl_low;
    logic       sda_in;
    logic       sda_prev;

    // Data Registers
    logic [7:0] addr_rw_reg, addr_rw_next;       // Received address + R/W bit
    logic [7:0] rx_shift, rx_shift_next;         // Receive shift register
    logic [7:0] tx_shift, tx_shift_next;         // Transmit shift register
    logic [2:0] bit_count, bit_count_next;       // Bit counter (0-7)

    // SDA Control
    logic       sda_out, sda_out_next;           // SDA output value
    logic       sda_oe, sda_oe_next;             // SDA output enable

    // Control Flags
    logic       addr_match, addr_match_next;     // Address matched
    logic       rw_bit;                          // Read/Write bit from address
    logic       ack_sent, ack_sent_next;         // ACK sent flag
    logic       data_valid_reg, data_valid_next; // Data valid pulse

    // START/STOP detection
    logic       start_detected;
    logic       stop_detected;

    //==========================================================================
    // SDA Tri-State Buffer
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign rx_data          = rx_shift;
    assign data_valid       = data_valid_reg;
    assign debug_addr_match = addr_match;
    assign debug_ack_sent   = ack_sent;
    assign debug_state      = state[1:0];  // Lower 2 bits for LED display
    assign debug_sda_out    = sda_out;
    assign debug_sda_oe     = sda_oe;

    //==========================================================================
    // SCL and SDA Synchronization (3-stage shift register)
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;  // Idle state is high
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
        end
    end

    // Edge detection
    assign scl_rising_edge  = (scl_sync[2:1] == 2'b01);
    assign scl_falling_edge = (scl_sync[2:1] == 2'b10);
    assign scl_high         = scl_sync[2];
    assign scl_low          = ~scl_sync[2];
    assign sda_in           = sda_sync[2];

    //==========================================================================
    // START and STOP Condition Detection
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_prev <= 1'b1;
        end else begin
            sda_prev <= sda_in;
        end
    end

    // START: SDA falls while SCL is high
    assign start_detected = (sda_prev & ~sda_in) & scl_high;

    // STOP: SDA rises while SCL is high
    assign stop_detected = (~sda_prev & sda_in) & scl_high;

    //==========================================================================
    // R/W Bit Extraction
    //==========================================================================
    assign rw_bit = addr_rw_reg[0];

    //==========================================================================
    // Sequential Logic
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            addr_rw_reg    <= 8'd0;
            rx_shift       <= 8'd0;
            tx_shift       <= 8'd0;
            bit_count      <= 3'd0;
            sda_out        <= 1'b1;
            sda_oe         <= 1'b0;  // Tri-state by default
            addr_match     <= 1'b0;
            ack_sent       <= 1'b0;
            data_valid_reg <= 1'b0;
        end else begin
            state          <= state_next;
            addr_rw_reg    <= addr_rw_next;
            rx_shift       <= rx_shift_next;
            tx_shift       <= tx_shift_next;
            bit_count      <= bit_count_next;
            sda_out        <= sda_out_next;
            sda_oe         <= sda_oe_next;
            addr_match     <= addr_match_next;
            ack_sent       <= ack_sent_next;
            data_valid_reg <= data_valid_next;
        end
    end

    //==========================================================================
    // Combinational FSM Logic
    //==========================================================================
    always_comb begin
        // Default: Hold current values
        state_next       = state;
        addr_rw_next     = addr_rw_reg;
        rx_shift_next    = rx_shift;
        tx_shift_next    = tx_shift;
        bit_count_next   = bit_count;
        sda_out_next     = sda_out;
        sda_oe_next      = sda_oe;
        addr_match_next  = addr_match;
        ack_sent_next    = ack_sent;
        data_valid_next  = 1'b0;  // Pulse signal

        // Detect STOP condition globally (except in IDLE)
        if (stop_detected && (state != IDLE)) begin
            state_next      = IDLE;
            sda_oe_next     = 1'b0;
            bit_count_next  = 3'd0;
            ack_sent_next   = 1'b0;
            addr_match_next = 1'b0;
        end else begin
            case (state)
                //==============================================================
                // IDLE: Wait for START condition
                //==============================================================
                IDLE: begin
                    sda_oe_next     = 1'b0;  // Tri-state
                    bit_count_next  = 3'd0;
                    ack_sent_next   = 1'b0;
                    addr_match_next = 1'b0;

                    if (start_detected) begin
                        state_next     = START;
                        bit_count_next = 3'd0;
                    end
                end

                //==============================================================
                // START: START condition detected, prepare to receive address
                //==============================================================
                START: begin
                    sda_oe_next    = 1'b0;  // Tri-state (receive mode)
                    bit_count_next = 3'd0;

                    if (scl_rising_edge) begin
                        state_next = ADDR_RCV;
                    end
                end

                //==============================================================
                // ADDR_RCV: Receive 8-bit address (7-bit addr + R/W)
                //==============================================================
                ADDR_RCV: begin
                    sda_oe_next = 1'b0;  // Tri-state (receive mode)

                    if (scl_rising_edge) begin
                        // Sample address bit on SCL rising edge
                        addr_rw_next = {addr_rw_reg[6:0], sda_in};
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            // All 8 bits received, check address
                            bit_count_next = 3'd0;
                            state_next     = ADDR_ACK;

                            // Check if address matches (compare upper 7 bits)
                            if ({addr_rw_reg[6:0], sda_in}[7:1] == slave_addr) begin
                                addr_match_next = 1'b1;
                            end else begin
                                addr_match_next = 1'b0;
                            end
                        end
                    end
                end

                //==============================================================
                // ADDR_ACK: Send ACK if address matched
                //==============================================================
                ADDR_ACK: begin
                    if (addr_match) begin
                        // Address matched - send ACK (drive SDA low)
                        if (scl_falling_edge) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;  // ACK
                            ack_sent_next = 1'b1;
                        end

                        if (scl_rising_edge) begin
                            // Keep ACK during SCL high
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;
                        end

                        if (scl_falling_edge && ack_sent) begin
                            // ACK period done, determine next state based on R/W
                            sda_oe_next = 1'b0;  // Release SDA

                            if (rw_bit == I2C_READ) begin
                                // Master wants to read - slave transmits
                                tx_shift_next = tx_data;
                                state_next    = DATA_SEND;
                            end else begin
                                // Master wants to write - slave receives
                                state_next = DATA_RCV;
                            end
                        end
                    end else begin
                        // Address didn't match - go back to IDLE, wait for STOP
                        sda_oe_next = 1'b0;  // Tri-state
                        state_next  = WAIT_STOP;
                    end
                end

                //==============================================================
                // DATA_RCV: Receive data byte (write operation)
                //==============================================================
                DATA_RCV: begin
                    sda_oe_next = 1'b0;  // Tri-state (receive mode)

                    if (scl_rising_edge) begin
                        // Sample data bit on SCL rising edge
                        rx_shift_next = {rx_shift[6:0], sda_in};
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            // All 8 bits received
                            bit_count_next  = 3'd0;
                            state_next      = DATA_ACK;
                            data_valid_next = 1'b1;  // Signal valid data
                        end
                    end
                end

                //==============================================================
                // DATA_SEND: Send data byte (read operation)
                //==============================================================
                DATA_SEND: begin
                    if (scl_falling_edge) begin
                        // Setup data bit on SCL falling edge
                        sda_oe_next  = 1'b1;
                        sda_out_next = tx_shift[7];  // MSB first
                    end

                    if (scl_rising_edge) begin
                        // Data stable during SCL high
                        bit_count_next = bit_count + 1;

                        if (bit_count == 7) begin
                            // All 8 bits sent
                            bit_count_next = 3'd0;
                            state_next     = DATA_ACK;
                        end else begin
                            // Shift to next bit
                            tx_shift_next = {tx_shift[6:0], 1'b0};
                        end
                    end
                end

                //==============================================================
                // DATA_ACK: Handle ACK for data byte
                //==============================================================
                DATA_ACK: begin
                    if (rw_bit == I2C_WRITE) begin
                        // Write: Send ACK to master
                        if (scl_falling_edge) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;  // ACK
                        end

                        if (scl_rising_edge) begin
                            sda_oe_next  = 1'b1;
                            sda_out_next = 1'b0;
                        end

                        if (scl_falling_edge && sda_oe) begin
                            // ACK sent, go to WAIT_STOP or receive more data
                            sda_oe_next = 1'b0;
                            state_next  = WAIT_STOP;  // Single byte transfer
                        end
                    end else begin
                        // Read: Wait for master's ACK/NACK
                        sda_oe_next = 1'b0;  // Release SDA

                        if (scl_rising_edge) begin
                            // Sample master's ACK/NACK
                            if (sda_in == 1'b1) begin
                                // NACK received - master done reading
                                state_next = WAIT_STOP;
                            end else begin
                                // ACK received - could send more bytes
                                // For single byte transfer, still go to WAIT_STOP
                                state_next = WAIT_STOP;
                            end
                        end
                    end
                end

                //==============================================================
                // WAIT_STOP: Wait for STOP condition
                //==============================================================
                WAIT_STOP: begin
                    sda_oe_next = 1'b0;  // Tri-state

                    // Detect repeated START
                    if (start_detected) begin
                        state_next     = START;
                        bit_count_next = 3'd0;
                        ack_sent_next  = 1'b0;
                    end
                end

                //==============================================================
                // ERROR: Error state
                //==============================================================
                ERROR: begin
                    sda_oe_next = 1'b0;
                    state_next  = IDLE;
                end

                //==============================================================
                // Default
                //==============================================================
                default: begin
                    state_next = IDLE;
                end
            endcase
        end
    end

endmodule : i2c_slave

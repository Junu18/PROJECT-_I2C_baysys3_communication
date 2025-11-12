`timescale 1ns / 1ps

//==============================================================================
// I2C Master for AXI Register Control
//==============================================================================
// Designed to interface directly with AXI-Lite registers
// Control via: i2c_en, i2c_start, i2c_stop
// Data via: tx_data (from AXI), rx_data (to AXI)
// Status via: tx_ready, tx_done, rx_done
//==============================================================================

module i2c_master (
    // Global signals
    input  logic       clk,
    input  logic       reset,

    // Control signals from AXI Control Register
    input  logic       i2c_en,         // Enable I2C operation
    input  logic       i2c_start,      // Start/Repeated Start
    input  logic       i2c_stop,       // Stop condition
    input  logic       i2c_rw,         // 0=Write, 1=Read

    // Data signals
    input  logic [6:0] slave_addr,     // 7-bit slave address (from AXI)
    input  logic [7:0] tx_data,        // Transmit data (from AXI ODR)
    output logic [7:0] rx_data,        // Receive data (to AXI IDR)

    // Status signals to AXI Status Register
    output logic       tx_ready,       // Ready to accept new TX data
    output logic       tx_done,        // TX complete
    output logic       rx_done,        // RX complete
    output logic       busy,           // I2C transaction in progress
    output logic       ack_error,      // NACK received

    // External I2C port
    inout  logic       sda,
    output logic       scl,

    // Debug ports
    output logic       debug_busy,
    output logic       debug_ack,
    output logic [3:0] debug_state,
    output logic       debug_scl,
    output logic       debug_sda_out,
    output logic       debug_sda_oe
);

    //==========================================================================
    // FSM States
    //==========================================================================
    typedef enum logic [4:0] {
        IDLE,
        HOLD,

        // Start condition
        START_1,
        START_2,

        // Address transmission (7-bit addr + R/W)
        ADDR_DATA_1,
        ADDR_DATA_2,
        ADDR_DATA_3,
        ADDR_DATA_4,

        // Address ACK
        ADDR_ACK_1,
        ADDR_ACK_2,
        ADDR_ACK_3,
        ADDR_ACK_4,

        // Write data transfer
        W_DATA_1,
        W_DATA_2,
        W_DATA_3,
        W_DATA_4,

        // Read data transfer
        R_DATA_1,
        R_DATA_2,
        R_DATA_3,
        R_DATA_4,

        // Write ACK (from slave)
        W_ACK_1,
        W_ACK_2,
        W_ACK_3,
        W_ACK_4,

        // Read ACK (master sends NACK)
        R_ACK_1,
        R_ACK_2,
        R_ACK_3,
        R_ACK_4,

        // Stop condition
        STOP_1,
        STOP_2
    } state_t;

    //==========================================================================
    // Internal Registers
    //==========================================================================
    state_t       state, state_next;
    logic [7:0]   addr_data_reg, addr_data_next;   // {slave_addr, rw_bit}
    logic [7:0]   tx_data_reg, tx_data_next;
    logic [7:0]   rx_data_reg, rx_data_next;
    logic [9:0]   clk_count_reg, clk_count_next;
    logic [2:0]   bit_count_reg, bit_count_next;
    logic         scl_reg, scl_next;
    logic         sda_oe, sda_out;
    logic         sda_in;

    // ACK check
    logic         ack_received_reg, ack_received_next;

    // Control flags
    logic         tx_done_reg, tx_done_next;
    logic         rx_done_reg, rx_done_next;

    //==========================================================================
    // SDA Tri-state Control
    //==========================================================================
    assign sda = sda_oe ? sda_out : 1'bz;
    assign sda_in = sda;
    assign scl = scl_reg;

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign rx_data    = rx_data_reg;
    assign tx_ready   = (state == IDLE) || (state == HOLD);
    assign tx_done    = tx_done_reg;
    assign rx_done    = rx_done_reg;
    assign busy       = (state != IDLE) && (state != HOLD);
    assign ack_error  = !ack_received_reg &&
                        ((state == ADDR_ACK_4) || (state == W_ACK_4));

    // Debug
    assign debug_busy     = busy;
    assign debug_ack      = ack_received_reg;
    assign debug_state    = state[3:0];
    assign debug_scl      = scl_reg;
    assign debug_sda_out  = sda_out;
    assign debug_sda_oe   = sda_oe;

    //==========================================================================
    // Sequential Logic
    //==========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            addr_data_reg    <= 8'd0;
            tx_data_reg      <= 8'd0;
            rx_data_reg      <= 8'd0;
            clk_count_reg    <= 10'd0;
            bit_count_reg    <= 3'd0;
            scl_reg          <= 1'b1;
            ack_received_reg <= 1'b0;
            tx_done_reg      <= 1'b0;
            rx_done_reg      <= 1'b0;
        end else begin
            state            <= state_next;
            addr_data_reg    <= addr_data_next;
            tx_data_reg      <= tx_data_next;
            rx_data_reg      <= rx_data_next;
            clk_count_reg    <= clk_count_next;
            bit_count_reg    <= bit_count_next;
            scl_reg          <= scl_next;
            ack_received_reg <= ack_received_next;
            tx_done_reg      <= tx_done_next;
            rx_done_reg      <= rx_done_next;
        end
    end

    //==========================================================================
    // Combinational FSM Logic
    //==========================================================================
    always_comb begin
        // Default: hold values
        state_next        = state;
        addr_data_next    = addr_data_reg;
        tx_data_next      = tx_data_reg;
        rx_data_next      = rx_data_reg;
        clk_count_next    = clk_count_reg;
        bit_count_next    = bit_count_reg;
        scl_next          = scl_reg;
        ack_received_next = ack_received_reg;
        tx_done_next      = 1'b0;  // Pulse
        rx_done_next      = 1'b0;  // Pulse

        sda_oe   = 1'b1;
        sda_out  = 1'b1;

        case (state)
            //==================================================================
            // IDLE: Wait for i2c_en
            //==================================================================
            IDLE: begin
                sda_oe  = 1'b1;
                sda_out = 1'b1;
                scl_next = 1'b1;

                if (i2c_en) begin
                    // Capture address and data
                    addr_data_next = {slave_addr, i2c_rw};
                    tx_data_next   = tx_data;
                    state_next     = START_1;
                end
            end

            //==================================================================
            // HOLD: Wait for next command from AXI
            //==================================================================
            HOLD: begin
                sda_oe  = 1'b1;
                sda_out = 1'b1;
                scl_next = 1'b1;

                if (i2c_start) begin
                    // Repeated START
                    addr_data_next = {slave_addr, i2c_rw};
                    tx_data_next   = tx_data;
                    state_next     = START_1;
                end else if (i2c_stop) begin
                    // STOP
                    state_next = STOP_1;
                end else if (i2c_en) begin
                    // Continue with data transfer based on current mode
                    if (addr_data_reg[0] == 1'b0) begin
                        // Write mode - load new data and write
                        tx_data_next = tx_data;
                        state_next   = W_DATA_1;
                    end else begin
                        // Read mode - read another byte
                        state_next = R_DATA_1;
                    end
                end
            end

            //==================================================================
            // START Condition
            //==================================================================
            START_1: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b1;
                scl_next = 1'b1;

                if (clk_count_reg == 499) begin
                    clk_count_next = 10'd0;
                    state_next     = START_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            START_2: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b0;  // SDA falls while SCL high
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    scl_next       = 1'b0;  // Then SCL goes low
                    state_next     = ADDR_DATA_1;
                    bit_count_next = 3'd0;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // ADDRESS Transmission (8 bits: 7-bit addr + R/W)
            //==================================================================
            ADDR_DATA_1: begin
                sda_oe   = 1'b1;
                sda_out  = addr_data_reg[7 - bit_count_reg];  // MSB first
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_DATA_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_DATA_2: begin
                sda_oe   = 1'b1;
                sda_out  = addr_data_reg[7 - bit_count_reg];
                scl_next = 1'b1;  // SCL high

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_DATA_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_DATA_3: begin
                sda_oe   = 1'b1;
                sda_out  = addr_data_reg[7 - bit_count_reg];
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_DATA_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_DATA_4: begin
                sda_oe   = 1'b1;
                sda_out  = addr_data_reg[7 - bit_count_reg];
                scl_next = 1'b0;  // SCL low

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;

                    if (bit_count_reg == 7) begin
                        // All 8 address bits sent
                        bit_count_next = 3'd0;
                        state_next     = ADDR_ACK_1;
                    end else begin
                        bit_count_next = bit_count_reg + 1;
                        state_next     = ADDR_DATA_1;
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // ADDRESS ACK
            //==================================================================
            ADDR_ACK_1: begin
                sda_oe   = 1'b0;  // Release for slave ACK
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_ACK_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_ACK_2: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;  // SCL high

                if (clk_count_reg == 124) begin
                    // Sample ACK in middle of SCL high
                    ack_received_next = ~sda_in;
                end

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_ACK_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_ACK_3: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = ADDR_ACK_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            ADDR_ACK_4: begin
                sda_oe   = 1'b0;
                scl_next = 1'b0;  // SCL low

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    bit_count_next = 3'd0;

                    if (!ack_received_reg) begin
                        // NACK - abort
                        state_next = STOP_1;
                    end else begin
                        // ACK - proceed based on R/W
                        if (addr_data_reg[0] == 1'b0) begin
                            // Write
                            state_next = W_DATA_1;
                        end else begin
                            // Read
                            state_next = R_DATA_1;
                        end
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // WRITE DATA
            //==================================================================
            W_DATA_1: begin
                sda_oe   = 1'b1;
                sda_out  = tx_data_reg[7 - bit_count_reg];
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_DATA_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_DATA_2: begin
                sda_oe   = 1'b1;
                sda_out  = tx_data_reg[7 - bit_count_reg];
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_DATA_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_DATA_3: begin
                sda_oe   = 1'b1;
                sda_out  = tx_data_reg[7 - bit_count_reg];
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_DATA_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_DATA_4: begin
                sda_oe   = 1'b1;
                sda_out  = tx_data_reg[7 - bit_count_reg];
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;

                    if (bit_count_reg == 7) begin
                        // All 8 bits sent
                        bit_count_next = 3'd0;
                        state_next     = W_ACK_1;
                    end else begin
                        bit_count_next = bit_count_reg + 1;
                        state_next     = W_DATA_1;
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // WRITE ACK
            //==================================================================
            W_ACK_1: begin
                sda_oe   = 1'b0;  // Release for ACK
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_ACK_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_ACK_2: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;

                if (clk_count_reg == 124) begin
                    ack_received_next = ~sda_in;
                end

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_ACK_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_ACK_3: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = W_ACK_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            W_ACK_4: begin
                sda_oe   = 1'b0;
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    tx_done_next   = 1'b1;  // Signal TX complete

                    if (!ack_received_reg) begin
                        state_next = STOP_1;
                    end else begin
                        state_next = HOLD;
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // READ DATA
            //==================================================================
            R_DATA_1: begin
                sda_oe   = 1'b0;  // Release for slave to drive
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_DATA_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_DATA_2: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;

                if (clk_count_reg == 124) begin
                    // Sample data in middle of SCL high
                    rx_data_next[7 - bit_count_reg] = sda_in;
                end

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_DATA_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_DATA_3: begin
                sda_oe   = 1'b0;
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_DATA_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_DATA_4: begin
                sda_oe   = 1'b0;
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;

                    if (bit_count_reg == 7) begin
                        // All 8 bits received
                        bit_count_next = 3'd0;
                        state_next     = R_ACK_1;
                    end else begin
                        bit_count_next = bit_count_reg + 1;
                        state_next     = R_DATA_1;
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // READ ACK (Master sends NACK)
            //==================================================================
            R_ACK_1: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b1;  // NACK
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_ACK_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_ACK_2: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b1;
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_ACK_3;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_ACK_3: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b1;
                scl_next = 1'b1;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    state_next     = R_ACK_4;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            R_ACK_4: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b1;
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    rx_done_next   = 1'b1;  // Signal RX complete
                    state_next     = HOLD;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            //==================================================================
            // STOP Condition
            //==================================================================
            STOP_1: begin
                sda_oe   = 1'b1;
                sda_out  = 1'b0;
                scl_next = 1'b0;

                if (clk_count_reg == 249) begin
                    clk_count_next = 10'd0;
                    scl_next       = 1'b1;  // SCL goes high first
                    state_next     = STOP_2;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            STOP_2: begin
                sda_oe   = 1'b1;
                scl_next = 1'b1;

                // SDA transitions: low (0-249) then high (250-499)
                if (clk_count_reg < 250) begin
                    sda_out = 1'b0;
                end else begin
                    sda_out = 1'b1;  // SDA rises while SCL high
                end

                if (clk_count_reg == 499) begin
                    clk_count_next = 10'd0;
                    state_next     = IDLE;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule

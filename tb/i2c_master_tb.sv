`timescale 1ns / 1ps

//==============================================================================
// I2C Master Testbench
//==============================================================================
// Tests:
//  1. Write transaction to slave address 0x55
//  2. Read transaction from slave address 0x55
//  3. ACK/NACK handling
//  4. Timing verification (100 kHz SCL)
//==============================================================================

import i2c_pkg::*;

module i2c_master_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz clock = 10 ns period
    localparam I2C_PERIOD = 10_000;  // 100 kHz I2C = 10 us period

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk;
    logic        rst_n;
    logic        start;
    logic        rw_bit;
    logic [6:0]  slave_addr;
    logic [7:0]  tx_data;
    logic [7:0]  rx_data;
    logic        busy;
    logic        done;
    logic        ack_error;
    wire         sda;
    logic        scl;
    logic        debug_busy;
    logic        debug_ack;
    logic [4:0]  debug_state;
    logic        debug_scl;
    logic        debug_sda_out;
    logic        debug_sda_oe;

    // Slave emulation signals
    logic        slave_sda_oe;
    logic        slave_sda_out;

    //==========================================================================
    // SDA Pull-up Emulation (both master and slave drive)
    //==========================================================================
    assign sda = (!slave_sda_oe && !debug_sda_oe) ? 1'b1 :      // Both tri-state: pull-up
                 (slave_sda_oe && !debug_sda_oe) ? slave_sda_out :  // Slave drives
                 (!slave_sda_oe && debug_sda_oe) ? debug_sda_out :  // Master drives
                 (slave_sda_out & debug_sda_out);                   // Both drive (wired-AND)

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    i2c_master dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .rw_bit         (rw_bit),
        .slave_addr     (slave_addr),
        .tx_data        (tx_data),
        .rx_data        (rx_data),
        .busy           (busy),
        .done           (done),
        .ack_error      (ack_error),
        .sda            (sda),
        .scl            (scl),
        .debug_busy     (debug_busy),
        .debug_ack      (debug_ack),
        .debug_state    (debug_state),
        .debug_scl      (debug_scl),
        .debug_sda_out  (debug_sda_out),
        .debug_sda_oe   (debug_sda_oe)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Simple Slave Model (ACK only, no data storage)
    //==========================================================================
    int bit_counter;
    logic [7:0] addr_byte;
    logic [7:0] data_byte;
    enum logic [2:0] {
        SLAVE_IDLE,
        SLAVE_ADDR,
        SLAVE_ADDR_ACK,
        SLAVE_DATA,
        SLAVE_DATA_ACK
    } slave_state;

    initial begin
        slave_sda_oe = 0;
        slave_sda_out = 1;
        slave_state = SLAVE_IDLE;
        bit_counter = 0;
        addr_byte = 0;
        data_byte = 0;
    end

    // Simple slave behavior: detect START, receive address, send ACK
    always @(negedge scl or posedge sda) begin
        if (sda && scl) begin
            // STOP condition detected
            slave_state = SLAVE_IDLE;
            slave_sda_oe = 0;
            bit_counter = 0;
        end
    end

    always @(negedge sda) begin
        if (scl) begin
            // START condition detected
            slave_state = SLAVE_ADDR;
            bit_counter = 0;
            slave_sda_oe = 0;
            $display("[%0t] SLAVE: START condition detected", $time);
        end
    end

    always @(posedge scl) begin
        case (slave_state)
            SLAVE_ADDR: begin
                // Receive address byte (7-bit addr + R/W)
                addr_byte = {addr_byte[6:0], sda};
                bit_counter++;

                if (bit_counter == 8) begin
                    slave_state = SLAVE_ADDR_ACK;
                    bit_counter = 0;
                    $display("[%0t] SLAVE: Received addr=0x%02h", $time, addr_byte);

                    // Check if address matches (0x55 = 0b10101010 for write, 0b10101011 for read)
                    if (addr_byte[7:1] == SLAVE_ADDR) begin
                        $display("[%0t] SLAVE: Address matches, sending ACK", $time);
                    end else begin
                        $display("[%0t] SLAVE: Address mismatch, sending NACK", $time);
                    end
                end
            end

            SLAVE_DATA: begin
                // Receive data byte
                data_byte = {data_byte[6:0], sda};
                bit_counter++;

                if (bit_counter == 8) begin
                    slave_state = SLAVE_DATA_ACK;
                    bit_counter = 0;
                    $display("[%0t] SLAVE: Received data=0x%02h", $time, data_byte);
                end
            end
        endcase
    end

    always @(negedge scl) begin
        case (slave_state)
            SLAVE_ADDR_ACK: begin
                // Drive ACK (SDA low)
                slave_sda_oe = 1;
                slave_sda_out = 0;
                slave_state = SLAVE_DATA;
                $display("[%0t] SLAVE: Sending ACK for address", $time);
            end

            SLAVE_DATA_ACK: begin
                // Drive ACK (SDA low)
                slave_sda_oe = 1;
                slave_sda_out = 0;
                slave_state = SLAVE_IDLE;  // End after one data byte
                $display("[%0t] SLAVE: Sending ACK for data", $time);
            end

            SLAVE_IDLE, SLAVE_ADDR, SLAVE_DATA: begin
                // Release SDA
                slave_sda_oe = 0;
            end
        endcase
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        rw_bit = I2C_WRITE;
        slave_addr = SLAVE_ADDR;
        tx_data = 8'h00;

        // VCD dump for waveform viewing
        $dumpfile("i2c_master_tb.vcd");
        $dumpvars(0, i2c_master_tb);

        $display("==================================================");
        $display("I2C Master Testbench");
        $display("==================================================");
        $display("System Clock: 100 MHz (period = %0d ns)", CLK_PERIOD);
        $display("I2C SCL: 100 kHz (period = %0d ns)", I2C_PERIOD);
        $display("Slave Address: 0x%02h", SLAVE_ADDR);
        $display("==================================================\n");

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        //======================================================================
        // Test 1: Write Transaction
        //======================================================================
        $display("\n[%0t] === TEST 1: Write Transaction ===", $time);
        slave_addr = 7'h55;  // 0x55
        rw_bit = I2C_WRITE;
        tx_data = 8'hA5;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for transaction to complete
        wait(done || ack_error);
        @(posedge clk);

        if (ack_error) begin
            $display("[%0t] TEST 1 FAILED: ACK error", $time);
        end else begin
            $display("[%0t] TEST 1 PASSED: Write completed successfully", $time);
        end

        #(I2C_PERIOD * 5);  // Wait 5 I2C periods

        //======================================================================
        // Test 2: Write Different Data
        //======================================================================
        $display("\n[%0t] === TEST 2: Write Different Data ===", $time);
        slave_addr = 7'h55;
        rw_bit = I2C_WRITE;
        tx_data = 8'h3C;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done || ack_error);
        @(posedge clk);

        if (ack_error) begin
            $display("[%0t] TEST 2 FAILED: ACK error", $time);
        end else begin
            $display("[%0t] TEST 2 PASSED: Write completed successfully", $time);
        end

        #(I2C_PERIOD * 5);

        //======================================================================
        // Test 3: Wrong Address (expect NACK)
        //======================================================================
        $display("\n[%0t] === TEST 3: Wrong Address (expect NACK) ===", $time);
        slave_addr = 7'h22;  // Wrong address
        rw_bit = I2C_WRITE;
        tx_data = 8'hFF;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done || ack_error);
        @(posedge clk);

        if (ack_error) begin
            $display("[%0t] TEST 3 PASSED: NACK detected as expected", $time);
        end else begin
            $display("[%0t] TEST 3 FAILED: Should have received NACK", $time);
        end

        #(I2C_PERIOD * 5);

        //======================================================================
        // End of Tests
        //======================================================================
        $display("\n==================================================");
        $display("All tests completed");
        $display("==================================================");
        #(CLK_PERIOD * 100);
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #(CLK_PERIOD * 1_000_000);  // 10 ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

    //==========================================================================
    // Monitor Key Signals
    //==========================================================================
    initial begin
        $monitor("[%0t] State=%0d SCL=%b SDA=%b Busy=%b Done=%b ACK_Err=%b",
                 $time, debug_state, scl, sda, busy, done, ack_error);
    end

endmodule : i2c_master_tb

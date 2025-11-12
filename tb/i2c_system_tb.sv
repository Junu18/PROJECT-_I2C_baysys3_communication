`timescale 1ns / 1ps

//==============================================================================
// I2C System Testbench (Master + Slave)
//==============================================================================
// Tests:
//  1. Master writes data to Slave
//  2. Master reads data from Slave
//  3. Address mismatch (slave ignores)
//  4. Full protocol verification
//==============================================================================

module i2c_system_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz clock = 10 ns period
    localparam I2C_PERIOD = 10_000;  // 100 kHz I2C = 10 us period

    // I2C Parameters
    localparam logic [6:0] SLAVE_ADDR = 7'b1010101;  // 0x55
    localparam logic I2C_WRITE = 1'b0;
    localparam logic I2C_READ  = 1'b1;

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk;
    logic        rst_n;

    // Master signals
    logic        master_start;
    logic        master_rw_bit;
    logic [6:0]  master_slave_addr;
    logic [7:0]  master_tx_data;
    logic [7:0]  master_rx_data;
    logic        master_busy;
    logic        master_done;
    logic        master_ack_error;
    logic        master_debug_busy;
    logic        master_debug_ack;
    logic [4:0]  master_debug_state;
    logic        master_debug_scl;
    logic        master_debug_sda_out;
    logic        master_debug_sda_oe;

    // Slave signals
    logic [7:0]  slave_tx_data;
    logic [7:0]  slave_rx_data;
    logic        slave_data_valid;
    logic        slave_debug_addr_match;
    logic        slave_debug_ack_sent;
    logic [1:0]  slave_debug_state;
    logic        slave_debug_sda_out;
    logic        slave_debug_sda_oe;

    // I2C Bus
    wire         scl;
    wire         sda;

    //==========================================================================
    // DUT Instantiation - Master
    //==========================================================================
    i2c_master master (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (master_start),
        .rw_bit         (master_rw_bit),
        .slave_addr     (master_slave_addr),
        .tx_data        (master_tx_data),
        .rx_data        (master_rx_data),
        .busy           (master_busy),
        .done           (master_done),
        .ack_error      (master_ack_error),
        .sda            (sda),
        .scl            (scl),
        .debug_busy     (master_debug_busy),
        .debug_ack      (master_debug_ack),
        .debug_state    (master_debug_state),
        .debug_scl      (master_debug_scl),
        .debug_sda_out  (master_debug_sda_out),
        .debug_sda_oe   (master_debug_sda_oe)
    );

    //==========================================================================
    // DUT Instantiation - Slave
    //==========================================================================
    i2c_slave slave (
        .clk                (clk),
        .rst_n              (rst_n),
        .slave_addr         (SLAVE_ADDR),
        .tx_data            (slave_tx_data),
        .rx_data            (slave_rx_data),
        .data_valid         (slave_data_valid),
        .scl                (scl),
        .sda                (sda),
        .debug_addr_match   (slave_debug_addr_match),
        .debug_ack_sent     (slave_debug_ack_sent),
        .debug_state        (slave_debug_state),
        .debug_sda_out      (slave_debug_sda_out),
        .debug_sda_oe       (slave_debug_sda_oe)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Initialize
        rst_n = 0;
        master_start = 0;
        master_rw_bit = I2C_WRITE;
        master_slave_addr = SLAVE_ADDR;
        master_tx_data = 8'h00;
        slave_tx_data = 8'h00;

        // VCD dump for waveform viewing
        $dumpfile("i2c_system_tb.vcd");
        $dumpvars(0, i2c_system_tb);

        $display("==================================================");
        $display("I2C System Testbench (Master + Slave)");
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
        // Test 1: Master Write to Slave
        //======================================================================
        $display("\n[%0t] === TEST 1: Master Write to Slave ===", $time);
        master_slave_addr = SLAVE_ADDR;  // 0x55
        master_rw_bit = I2C_WRITE;
        master_tx_data = 8'hA5;

        @(posedge clk);
        master_start = 1;
        @(posedge clk);
        master_start = 0;

        // Wait for transaction to complete
        wait(master_done || master_ack_error);
        @(posedge clk);

        if (master_ack_error) begin
            $display("[%0t] TEST 1 FAILED: Master received NACK", $time);
        end else if (slave_data_valid) begin
            $display("[%0t] TEST 1 PASSED: Slave received data = 0x%02h", $time, slave_rx_data);
            if (slave_rx_data == 8'hA5) begin
                $display("[%0t] TEST 1 VERIFIED: Data matches!", $time);
            end else begin
                $display("[%0t] TEST 1 FAILED: Data mismatch! Expected 0xA5, got 0x%02h", $time, slave_rx_data);
            end
        end else begin
            $display("[%0t] TEST 1 FAILED: Slave did not receive data", $time);
        end

        #(I2C_PERIOD * 5);  // Wait 5 I2C periods

        //======================================================================
        // Test 2: Master Read from Slave
        //======================================================================
        $display("\n[%0t] === TEST 2: Master Read from Slave ===", $time);
        master_slave_addr = SLAVE_ADDR;
        master_rw_bit = I2C_READ;
        slave_tx_data = 8'h3C;  // Data slave will send

        @(posedge clk);
        master_start = 1;
        @(posedge clk);
        master_start = 0;

        wait(master_done || master_ack_error);
        @(posedge clk);

        if (master_ack_error) begin
            $display("[%0t] TEST 2 FAILED: Master received NACK", $time);
        end else begin
            $display("[%0t] TEST 2 PASSED: Master received data = 0x%02h", $time, master_rx_data);
            if (master_rx_data == 8'h3C) begin
                $display("[%0t] TEST 2 VERIFIED: Data matches!", $time);
            end else begin
                $display("[%0t] TEST 2 FAILED: Data mismatch! Expected 0x3C, got 0x%02h", $time, master_rx_data);
            end
        end

        #(I2C_PERIOD * 5);

        //======================================================================
        // Test 3: Different Data Write
        //======================================================================
        $display("\n[%0t] === TEST 3: Master Write Different Data ===", $time);
        master_slave_addr = SLAVE_ADDR;
        master_rw_bit = I2C_WRITE;
        master_tx_data = 8'h5A;

        @(posedge clk);
        master_start = 1;
        @(posedge clk);
        master_start = 0;

        wait(master_done || master_ack_error);
        @(posedge clk);

        if (master_ack_error) begin
            $display("[%0t] TEST 3 FAILED: Master received NACK", $time);
        end else if (slave_data_valid) begin
            $display("[%0t] TEST 3 PASSED: Slave received data = 0x%02h", $time, slave_rx_data);
            if (slave_rx_data == 8'h5A) begin
                $display("[%0t] TEST 3 VERIFIED: Data matches!", $time);
            end else begin
                $display("[%0t] TEST 3 FAILED: Data mismatch!", $time);
            end
        end

        #(I2C_PERIOD * 5);

        //======================================================================
        // Test 4: Wrong Address (Slave should ignore)
        //======================================================================
        $display("\n[%0t] === TEST 4: Wrong Address (expect NACK) ===", $time);
        master_slave_addr = 7'h22;  // Wrong address
        master_rw_bit = I2C_WRITE;
        master_tx_data = 8'hFF;

        @(posedge clk);
        master_start = 1;
        @(posedge clk);
        master_start = 0;

        wait(master_done || master_ack_error);
        @(posedge clk);

        if (master_ack_error) begin
            $display("[%0t] TEST 4 PASSED: Master correctly received NACK for wrong address", $time);
        end else begin
            $display("[%0t] TEST 4 FAILED: Should have received NACK", $time);
        end

        #(I2C_PERIOD * 5);

        //======================================================================
        // Test 5: Multiple Sequential Writes
        //======================================================================
        $display("\n[%0t] === TEST 5: Multiple Sequential Writes ===", $time);
        for (int i = 0; i < 3; i++) begin
            master_slave_addr = SLAVE_ADDR;
            master_rw_bit = I2C_WRITE;
            master_tx_data = 8'h10 + i;

            @(posedge clk);
            master_start = 1;
            @(posedge clk);
            master_start = 0;

            wait(master_done || master_ack_error);
            @(posedge clk);

            if (!master_ack_error && slave_data_valid) begin
                $display("[%0t] Write %0d: Sent 0x%02h, Received 0x%02h", $time, i, 8'h10+i, slave_rx_data);
            end

            #(I2C_PERIOD * 3);
        end

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
        #(CLK_PERIOD * 10_000_000);  // 100 ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

    //==========================================================================
    // Monitor Key Signals
    //==========================================================================
    initial begin
        $monitor("[%0t] Master: State=%0d Busy=%b Done=%b | Slave: State=%0d AddrMatch=%b DataValid=%b | SCL=%b SDA=%b",
                 $time, master_debug_state, master_busy, master_done,
                 slave_debug_state, slave_debug_addr_match, slave_data_valid,
                 scl, sda);
    end

    //==========================================================================
    // Data Valid Monitor
    //==========================================================================
    always @(posedge clk) begin
        if (slave_data_valid) begin
            $display("[%0t] *** SLAVE RECEIVED DATA: 0x%02h ***", $time, slave_rx_data);
        end
    end

endmodule : i2c_system_tb

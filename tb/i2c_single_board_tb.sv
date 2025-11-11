`timescale 1ns / 1ps

//==============================================================================
// I2C Single Board Testbench
//==============================================================================
// Tests the integrated Master + Slave on single board
//==============================================================================

module i2c_single_board_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz clock = 10 ns period

    //==========================================================================
    // Signals
    //==========================================================================
    logic        clk;
    logic        rst_n;
    logic        btn_start;
    logic        btn_mode;
    logic        btn_loopback;
    logic [7:0]  sw_tx_data;
    logic        sw_rw;
    logic [6:0]  sw_slave_addr;
    logic [7:0]  led_data;
    logic        led_master_busy;
    logic        led_master_done;
    logic        led_master_ack;
    logic        led_slave_match;
    logic        led_slave_valid;
    logic        led_scl;
    logic        led_sda;
    logic        led_loopback;
    wire         pmod_scl;
    wire         pmod_sda;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    i2c_single_board_top dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .btn_start        (btn_start),
        .btn_mode         (btn_mode),
        .btn_loopback     (btn_loopback),
        .sw_tx_data       (sw_tx_data),
        .sw_rw            (sw_rw),
        .sw_slave_addr    (sw_slave_addr),
        .led_data         (led_data),
        .led_master_busy  (led_master_busy),
        .led_master_done  (led_master_done),
        .led_master_ack   (led_master_ack),
        .led_slave_match  (led_slave_match),
        .led_slave_valid  (led_slave_valid),
        .led_scl          (led_scl),
        .led_sda          (led_sda),
        .led_loopback     (led_loopback),
        .pmod_scl         (pmod_scl),
        .pmod_sda         (pmod_sda)
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
        btn_start = 0;
        btn_mode = 0;
        btn_loopback = 0;
        sw_tx_data = 8'h00;
        sw_rw = 0;
        sw_slave_addr = 7'b1010101;  // 0x55

        // VCD dump
        $dumpfile("i2c_single_board_tb.vcd");
        $dumpvars(0, i2c_single_board_tb);

        $display("==================================================");
        $display("I2C Single Board Testbench");
        $display("==================================================");
        $display("Testing Master + Slave on single Basys3 board");
        $display("Loopback mode enabled by default");
        $display("==================================================\n");

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        //======================================================================
        // Test 1: Write Transaction
        //======================================================================
        $display("\n[%0t] === TEST 1: Write 0xA5 ===", $time);
        sw_tx_data = 8'hA5;
        sw_rw = 1'b0;  // Write
        sw_slave_addr = 7'h55;

        // Press start button
        #(CLK_PERIOD * 10);
        btn_start = 1;
        #(CLK_PERIOD * 1_000_000);  // Hold button for 10ms
        btn_start = 0;

        // Wait for transaction to complete
        wait(led_master_done);
        #(CLK_PERIOD * 100);

        if (led_master_ack && led_slave_valid) begin
            $display("[%0t] TEST 1 PASSED: Slave received data = 0x%02h", $time, dut.slave_rx_data);
        end else begin
            $display("[%0t] TEST 1 FAILED", $time);
        end

        #(CLK_PERIOD * 10000);  // Wait

        //======================================================================
        // Test 2: Read Transaction
        //======================================================================
        $display("\n[%0t] === TEST 2: Read from Slave ===", $time);
        sw_tx_data = 8'h3C;  // Not used in read, but slave will send ~0x3C = 0xC3
        sw_rw = 1'b1;  // Read
        sw_slave_addr = 7'h55;

        // Press start button
        #(CLK_PERIOD * 10);
        btn_start = 1;
        #(CLK_PERIOD * 1_000_000);
        btn_start = 0;

        // Wait for transaction
        wait(led_master_done);
        #(CLK_PERIOD * 100);

        if (led_master_ack) begin
            $display("[%0t] TEST 2 PASSED: Master received data = 0x%02h", $time, dut.master_rx_data);
        end else begin
            $display("[%0t] TEST 2 FAILED", $time);
        end

        #(CLK_PERIOD * 10000);

        //======================================================================
        // Test 3: Display Mode Toggle
        //======================================================================
        $display("\n[%0t] === TEST 3: Toggle Display Mode ===", $time);
        $display("[%0t] Current LED data (Master TX): 0x%02h", $time, led_data);

        // Toggle mode
        btn_mode = 1;
        #(CLK_PERIOD * 1_000_000);
        btn_mode = 0;
        #(CLK_PERIOD * 100);

        $display("[%0t] After toggle (Slave RX): 0x%02h", $time, led_data);

        #(CLK_PERIOD * 10000);

        //======================================================================
        // Test 4: Multiple Writes
        //======================================================================
        $display("\n[%0t] === TEST 4: Multiple Sequential Writes ===", $time);
        for (int i = 0; i < 3; i++) begin
            sw_tx_data = 8'h10 + i;
            sw_rw = 1'b0;

            btn_start = 1;
            #(CLK_PERIOD * 1_000_000);
            btn_start = 0;

            wait(led_master_done);
            #(CLK_PERIOD * 100);

            $display("[%0t] Write %0d: Sent 0x%02h, Slave RX = 0x%02h",
                     $time, i, 8'h10+i, dut.slave_rx_data);

            #(CLK_PERIOD * 10000);
        end

        //======================================================================
        // End of Tests
        //======================================================================
        $display("\n==================================================");
        $display("All tests completed");
        $display("==================================================");
        #(CLK_PERIOD * 1000);
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #(CLK_PERIOD * 100_000_000);  // 1 second timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

    //==========================================================================
    // Monitor
    //==========================================================================
    initial begin
        $monitor("[%0t] Master: Busy=%b Done=%b ACK=%b | Slave: Match=%b Valid=%b | SCL=%b SDA=%b | LED_Data=0x%02h",
                 $time, led_master_busy, led_master_done, led_master_ack,
                 led_slave_match, led_slave_valid, led_scl, led_sda, led_data);
    end

endmodule : i2c_single_board_tb

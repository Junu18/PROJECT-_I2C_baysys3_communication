`timescale 1ns / 1ps

//==============================================================================
// Simple I2C Debug Testbench
//==============================================================================
// Minimal testbench for quick debugging
// Tests only one slave at a time with detailed debug output
//==============================================================================

module i2c_simple_debug_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz

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
    logic [7:0]  SW;
    logic [7:0]  LED;
    logic [6:0]  SEG;
    logic [3:0]  AN;

    // Debug
    logic        debug_addr_match_led;
    logic        debug_addr_match_fnd;
    logic        debug_addr_match_sw;
    logic [4:0]  debug_master_state;
    logic [3:0]  debug_led_state;
    logic [3:0]  debug_fnd_state;
    logic [3:0]  debug_sw_state;

    //==========================================================================
    // DUT
    //==========================================================================
    i2c_system_top dut (
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
        .SW(SW),
        .LED(LED),
        .SEG(SEG),
        .AN(AN),
        .debug_addr_match_led(debug_addr_match_led),
        .debug_addr_match_fnd(debug_addr_match_fnd),
        .debug_addr_match_sw(debug_addr_match_sw),
        .debug_master_state(debug_master_state),
        .debug_led_state(debug_led_state),
        .debug_fnd_state(debug_fnd_state),
        .debug_sw_state(debug_sw_state)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Debug Monitor (Address Match Only)
    //==========================================================================
    logic prev_addr_match_led, prev_addr_match_fnd, prev_addr_match_sw;

    always @(posedge clk) begin
        prev_addr_match_led <= debug_addr_match_led;
        prev_addr_match_fnd <= debug_addr_match_fnd;
        prev_addr_match_sw  <= debug_addr_match_sw;

        // Only print on rising edge of addr_match
        if (debug_addr_match_led && !prev_addr_match_led)
            $display("  [DEBUG] LED SLAVE ADDRESSED");
        if (debug_addr_match_fnd && !prev_addr_match_fnd)
            $display("  [DEBUG] FND SLAVE ADDRESSED");
        if (debug_addr_match_sw && !prev_addr_match_sw)
            $display("  [DEBUG] SWITCH SLAVE ADDRESSED");
    end

    //==========================================================================
    // Test Sequence
    //==========================================================================
    int test_pass = 0;
    int test_fail = 0;

    initial begin
        $display("========================================");
        $display("Simple I2C Debug Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        start = 0;
        rw_bit = 0;
        slave_addr = 7'h00;
        tx_data = 8'h00;
        SW = 8'hAB;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        //======================================================================
        // Test 1: Write to LED Slave (0x55)
        //======================================================================
        $display("Test 1: Write 0xFF to LED (0x55)");

        slave_addr = 7'h55;
        tx_data = 8'hFF;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for done
        wait(done == 1);
        @(posedge clk);

        if (LED == 8'hFF && !ack_error) begin
            $display("  ✓ PASS: LED=0x%02h, ACK error=%b\n", LED, ack_error);
            test_pass++;
        end else begin
            $display("  ✗ FAIL: LED=0x%02h (expected 0xFF), ACK error=%b\n", LED, ack_error);
            test_fail++;
        end

        repeat(50) @(posedge clk);

        //======================================================================
        // Test 2: Write to FND Slave (0x56)
        //======================================================================
        $display("Test 2: Write 0x05 to FND (0x56)");

        slave_addr = 7'h56;
        tx_data = 8'h05;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        if (SEG == 7'b0010010 && !ack_error) begin
            $display("  ✓ PASS: SEG=7'b%07b, ACK error=%b\n", SEG, ack_error);
            test_pass++;
        end else begin
            $display("  ✗ FAIL: SEG=7'b%07b (expected 7'b0010010), ACK error=%b\n", SEG, ack_error);
            test_fail++;
        end

        repeat(50) @(posedge clk);

        //======================================================================
        // Test 3: Read from Switch Slave (0x57)
        //======================================================================
        $display("Test 3: Read from Switch (0x57)");

        SW = 8'hCD;
        slave_addr = 7'h57;
        rw_bit = 1'b1;  // Read

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        if (rx_data == 8'hCD && !ack_error) begin
            $display("  ✓ PASS: rx_data=0x%02h, ACK error=%b\n", rx_data, ack_error);
            test_pass++;
        end else begin
            $display("  ✗ FAIL: rx_data=0x%02h (expected 0xCD), ACK error=%b\n", rx_data, ack_error);
            test_fail++;
        end

        repeat(50) @(posedge clk);

        //======================================================================
        // Test 4: Invalid Address
        //======================================================================
        $display("Test 4: Invalid Address (0x99)");

        slave_addr = 7'h99;
        tx_data = 8'hFF;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        if (ack_error) begin
            $display("  ✓ PASS: ACK error=%b (correctly detected)\n", ack_error);
            test_pass++;
        end else begin
            $display("  ✗ FAIL: ACK error=%b (should be 1)\n", ack_error);
            test_fail++;
        end

        repeat(50) @(posedge clk);

        //======================================================================
        // Summary
        //======================================================================
        $display("========================================");
        $display("FINAL RESULTS:");
        $display("  PASSED: %0d/4", test_pass);
        $display("  FAILED: %0d/4", test_fail);
        $display("========================================");

        if (test_fail == 0) begin
            $display("✓ ALL TESTS PASSED!\n");
        end else begin
            $display("✗ SOME TESTS FAILED!\n");
        end

        $finish;
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_simple_debug_tb.vcd");
        $dumpvars(0, i2c_simple_debug_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #10000000;  // 10ms timeout
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

endmodule

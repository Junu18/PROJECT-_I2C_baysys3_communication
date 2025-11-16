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
    // Debug Monitor
    //==========================================================================
    always @(posedge clk) begin
        if (debug_addr_match_led)
            $display("[%0t] *** LED SLAVE ADDRESSED ***", $time);
        if (debug_addr_match_fnd)
            $display("[%0t] *** FND SLAVE ADDRESSED ***", $time);
        if (debug_addr_match_sw)
            $display("[%0t] *** SWITCH SLAVE ADDRESSED ***", $time);
    end

    // State monitor
    always @(posedge clk) begin
        if (debug_led_state != 0)
            $display("[%0t] LED State: %0d", $time, debug_led_state);
    end

    //==========================================================================
    // Test Sequence
    //==========================================================================
    initial begin
        $display("========================================");
        $display("Simple I2C Debug Testbench");
        $display("========================================");

        // Initialize
        rst_n = 0;
        start = 0;
        rw_bit = 0;
        slave_addr = 7'h00;
        tx_data = 8'h00;
        SW = 8'hAB;

        repeat(10) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);
        repeat(10) @(posedge clk);

        //======================================================================
        // Test 1: Write to LED Slave (0x55)
        //======================================================================
        $display("\n[%0t] === Test 1: Write 0xFF to LED (0x55) ===", $time);

        slave_addr = 7'h55;
        tx_data = 8'hFF;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        $display("[%0t] Start pulse", $time);
        @(posedge clk);
        start = 0;

        // Wait for done
        $display("[%0t] Waiting for done...", $time);
        wait(done == 1);
        $display("[%0t] Done signal received", $time);
        @(posedge clk);

        $display("[%0t] Results:", $time);
        $display("  LED = 0x%02h (expected 0xFF)", LED);
        $display("  ACK error = %b (expected 0)", ack_error);
        $display("  debug_addr_match_led = %b", debug_addr_match_led);

        if (LED == 8'hFF && !ack_error) begin
            $display("  ✓ TEST PASSED!");
        end else begin
            $display("  ✗ TEST FAILED!");
        end

        repeat(100) @(posedge clk);

        //======================================================================
        // Test 2: Write to FND Slave (0x56)
        //======================================================================
        $display("\n[%0t] === Test 2: Write 0x05 to FND (0x56) ===", $time);

        slave_addr = 7'h56;
        tx_data = 8'h05;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        $display("[%0t] Results:", $time);
        $display("  SEG = 7'b%07b (expected 7'b0010010)", SEG);
        $display("  ACK error = %b (expected 0)", ack_error);
        $display("  debug_addr_match_fnd = %b", debug_addr_match_fnd);

        if (SEG == 7'b0010010 && !ack_error) begin
            $display("  ✓ TEST PASSED!");
        end else begin
            $display("  ✗ TEST FAILED!");
        end

        repeat(100) @(posedge clk);

        //======================================================================
        // Test 3: Read from Switch Slave (0x57)
        //======================================================================
        $display("\n[%0t] === Test 3: Read from Switch (0x57) ===", $time);

        SW = 8'hCD;
        slave_addr = 7'h57;
        rw_bit = 1'b1;  // Read

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        $display("[%0t] Results:", $time);
        $display("  rx_data = 0x%02h (expected 0xCD)", rx_data);
        $display("  ACK error = %b (expected 0)", ack_error);
        $display("  debug_addr_match_sw = %b", debug_addr_match_sw);

        if (rx_data == 8'hCD && !ack_error) begin
            $display("  ✓ TEST PASSED!");
        end else begin
            $display("  ✗ TEST FAILED!");
        end

        repeat(100) @(posedge clk);

        //======================================================================
        // Test 4: Invalid Address
        //======================================================================
        $display("\n[%0t] === Test 4: Invalid Address (0x99) ===", $time);

        slave_addr = 7'h99;
        tx_data = 8'hFF;
        rw_bit = 1'b0;  // Write

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk);

        $display("[%0t] Results:", $time);
        $display("  ACK error = %b (expected 1)", ack_error);

        if (ack_error) begin
            $display("  ✓ TEST PASSED!");
        end else begin
            $display("  ✗ TEST FAILED!");
        end

        repeat(100) @(posedge clk);

        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("Debug Tests Complete");
        $display("========================================");

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

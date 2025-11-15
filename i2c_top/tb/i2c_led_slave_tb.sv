`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C LED Slave
//==============================================================================
// Tests LED control via I2C single-byte write protocol
//==============================================================================

module i2c_led_slave_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD   = 10;       // 100 MHz
    localparam CLK_PER_BIT  = 250;      // Quarter bit period
    localparam HALF_PERIOD  = 500;      // Half SCL period
    localparam SLAVE_ADDR   = 7'h55;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;
    logic       scl;
    wire        sda;
    logic [7:0] LED;
    logic       debug_addr_match;
    logic [3:0] debug_state;

    // Master simulator
    logic       master_scl;
    logic       master_sda_oe;
    logic       master_sda_out;

    // Test control
    int         test_pass;
    int         test_fail;

    //==========================================================================
    // I2C Bus
    //==========================================================================
    assign scl = master_scl;
    assign sda = master_sda_oe ? master_sda_out : 1'bz;

    //==========================================================================
    // DUT
    //==========================================================================
    i2c_led_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .LED(LED),
        .debug_addr_match(debug_addr_match),
        .debug_state(debug_state)
    );

    //==========================================================================
    // Clock
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Test Sequence
    //==========================================================================
    initial begin
        $display("========================================");
        $display("I2C LED Slave Testbench");
        $display("Address: 0x55 (7-bit)");
        $display("========================================");

        test_pass = 0;
        test_fail = 0;

        // Initialize
        rst_n = 0;
        master_scl = 1;
        master_sda_oe = 0;
        master_sda_out = 1;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);

        $display("\n[%0t] === Test 1: Write 0xFF (All LEDs ON) ===", $time);
        test_write_led(8'hFF);
        repeat(100) @(posedge clk);
        if (LED == 8'hFF) begin
            $display("  ✓ LED = 0xFF");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0xFF (got 0x%02h)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 2: Write 0x00 (All LEDs OFF) ===", $time);
        test_write_led(8'h00);
        repeat(100) @(posedge clk);
        if (LED == 8'h00) begin
            $display("  ✓ LED = 0x00");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0x00 (got 0x%02h)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 3: Write 0xAA (Pattern) ===", $time);
        test_write_led(8'hAA);
        repeat(100) @(posedge clk);
        if (LED == 8'hAA) begin
            $display("  ✓ LED = 0xAA");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0xAA (got 0x%02h)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 4: Write 0x55 (Pattern) ===", $time);
        test_write_led(8'h55);
        repeat(100) @(posedge clk);
        if (LED == 8'h55) begin
            $display("  ✓ LED = 0x55");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0x55 (got 0x%02h)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 5: Multiple Writes ===", $time);
        test_write_led(8'h01);
        repeat(50) @(posedge clk);
        test_write_led(8'h02);
        repeat(50) @(posedge clk);
        test_write_led(8'h04);
        repeat(50) @(posedge clk);
        test_write_led(8'h08);
        repeat(100) @(posedge clk);
        if (LED == 8'h08) begin
            $display("  ✓ LED = 0x08 (last write)");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0x08 (got 0x%02h)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        // Summary
        $display("\n========================================");
        $display("Test Summary:");
        $display("  PASSED: %0d", test_pass);
        $display("  FAILED: %0d", test_fail);
        $display("========================================");

        if (test_fail == 0) begin
            $display("✓ ALL TESTS PASSED!");
        end else begin
            $display("✗ SOME TESTS FAILED!");
        end

        $finish;
    end

    //==========================================================================
    // Master Simulator Tasks
    //==========================================================================

    task i2c_start();
        begin
            $display("  [%0t] START", $time);
            master_sda_oe = 1;
            master_sda_out = 1;
            master_scl = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            master_sda_out = 0;
            repeat(HALF_PERIOD) @(posedge clk);

            master_scl = 0;
            repeat(HALF_PERIOD) @(posedge clk);
        end
    endtask

    task i2c_stop();
        begin
            $display("  [%0t] STOP", $time);
            master_sda_oe = 1;
            master_sda_out = 0;
            master_scl = 0;
            repeat(HALF_PERIOD) @(posedge clk);

            master_scl = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            master_sda_out = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            master_sda_oe = 0;
        end
    endtask

    task i2c_send_bit(input bit value);
        begin
            master_sda_oe = 1;
            master_sda_out = value;

            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);

            master_scl = 1;
            repeat(CLK_PER_BIT) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);
        end
    endtask

    task i2c_send_byte(input [7:0] data);
        begin
            for (int i = 7; i >= 0; i--) begin
                i2c_send_bit(data[i]);
            end
        end
    endtask

    task i2c_receive_ack(output bit ack);
        begin
            master_sda_oe = 0;

            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);

            master_scl = 1;
            repeat(CLK_PER_BIT/2) @(posedge clk);
            ack = ~sda;
            repeat(CLK_PER_BIT/2) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);
        end
    endtask

    //==========================================================================
    // High-level Test Tasks
    //==========================================================================

    task test_write_led(input [7:0] data);
        bit ack;
        begin
            $display("  Write LED: 0x%02h", data);

            i2c_start();

            // Device address + Write
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for device addr");

            // Data
            i2c_send_byte(data);
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for data");

            i2c_stop();
        end
    endtask

    //==========================================================================
    // Waveform
    //==========================================================================
    initial begin
        $dumpfile("i2c_led_slave_tb.vcd");
        $dumpvars(0, i2c_led_slave_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #50000000;
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

endmodule

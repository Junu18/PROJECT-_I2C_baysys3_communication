`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Switch Slave
//==============================================================================
// Tests switch reading via I2C single-byte read protocol
//==============================================================================

module i2c_switch_slave_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD   = 10;       // 100 MHz
    localparam CLK_PER_BIT  = 250;      // Quarter bit period
    localparam HALF_PERIOD  = 500;      // Half SCL period
    localparam SLAVE_ADDR   = 7'h57;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;
    logic       scl;
    wire        sda;
    logic [7:0] SW;
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
    i2c_switch_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SW(SW),
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
        $display("I2C Switch Slave Testbench");
        $display("Address: 0x57 (7-bit)");
        $display("========================================");

        test_pass = 0;
        test_fail = 0;

        // Initialize
        rst_n = 0;
        SW = 8'h00;
        master_scl = 1;
        master_sda_oe = 0;
        master_sda_out = 1;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);

        $display("\n[%0t] === Test 1: Read SW=0x00 ===", $time);
        SW = 8'h00;
        test_read_switch(8'h00);
        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 2: Read SW=0xFF ===", $time);
        SW = 8'hFF;
        test_read_switch(8'hFF);
        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 3: Read SW=0xAA ===", $time);
        SW = 8'hAA;
        test_read_switch(8'hAA);
        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 4: Read SW=0x55 ===", $time);
        SW = 8'h55;
        test_read_switch(8'h55);
        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 5: Read SW=0x12 ===", $time);
        SW = 8'h12;
        test_read_switch(8'h12);
        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 6: Multiple Reads ===", $time);
        SW = 8'h01;
        test_read_switch(8'h01);
        repeat(50) @(posedge clk);
        SW = 8'h02;
        test_read_switch(8'h02);
        repeat(50) @(posedge clk);
        SW = 8'h04;
        test_read_switch(8'h04);
        repeat(50) @(posedge clk);
        SW = 8'h08;
        test_read_switch(8'h08);
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

    task i2c_receive_byte(output [7:0] data);
        begin
            master_sda_oe = 0;
            data = 8'h00;

            for (int i = 7; i >= 0; i--) begin
                master_scl = 0;
                repeat(CLK_PER_BIT) @(posedge clk);
                repeat(CLK_PER_BIT) @(posedge clk);

                master_scl = 1;
                repeat(CLK_PER_BIT/2) @(posedge clk);
                data[i] = sda;
                repeat(CLK_PER_BIT/2) @(posedge clk);
                repeat(CLK_PER_BIT) @(posedge clk);
            end
        end
    endtask

    task i2c_send_nack();
        begin
            master_sda_oe = 1;
            master_sda_out = 1;

            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);

            master_scl = 1;
            repeat(CLK_PER_BIT) @(posedge clk);
            repeat(CLK_PER_BIT) @(posedge clk);

            master_sda_oe = 0;
        end
    endtask

    //==========================================================================
    // High-level Test Tasks
    //==========================================================================

    task test_read_switch(input [7:0] expected);
        bit ack;
        logic [7:0] data;
        begin
            $display("  Read Switch (expect 0x%02h)", expected);

            i2c_start();

            // Device address + Read
            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for device addr");

            // Read data
            i2c_receive_byte(data);
            i2c_send_nack();

            i2c_stop();

            if (data == expected) begin
                $display("  ✓ Read data matches: 0x%02h", data);
                test_pass++;
            end else begin
                $display("  ✗ Read mismatch: expected 0x%02h, got 0x%02h", expected, data);
                test_fail++;
            end
        end
    endtask

    //==========================================================================
    // Waveform
    //==========================================================================
    initial begin
        $dumpfile("i2c_switch_slave_tb.vcd");
        $dumpvars(0, i2c_switch_slave_tb);
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

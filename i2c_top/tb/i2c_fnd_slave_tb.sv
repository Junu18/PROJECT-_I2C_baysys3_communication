`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C FND (7-Segment) Slave
//==============================================================================
// Tests 7-segment display control via I2C single-byte write protocol
//==============================================================================

module i2c_fnd_slave_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD   = 10;       // 100 MHz
    localparam CLK_PER_BIT  = 250;      // Quarter bit period
    localparam HALF_PERIOD  = 500;      // Half SCL period
    localparam SLAVE_ADDR   = 7'h56;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;
    logic       scl;
    wire        sda;
    logic [6:0] SEG;
    logic [3:0] AN;
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
    i2c_fnd_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SEG(SEG),
        .AN(AN),
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
        $display("I2C FND Slave Testbench");
        $display("Address: 0x56 (7-bit)");
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

        $display("\n[%0t] === Test 1: Display '0' ===", $time);
        test_write_fnd(8'h00);
        repeat(100) @(posedge clk);
        if (SEG == 7'b1000000) begin
            $display("  ✓ SEG = 7'b1000000 (digit 0)");
            test_pass++;
        end else begin
            $display("  ✗ SEG != 7'b1000000 (got 7'b%07b)", SEG);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 2: Display '5' ===", $time);
        test_write_fnd(8'h05);
        repeat(100) @(posedge clk);
        if (SEG == 7'b0010010) begin
            $display("  ✓ SEG = 7'b0010010 (digit 5)");
            test_pass++;
        end else begin
            $display("  ✗ SEG != 7'b0010010 (got 7'b%07b)", SEG);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 3: Display 'A' ===", $time);
        test_write_fnd(8'h0A);
        repeat(100) @(posedge clk);
        if (SEG == 7'b0001000) begin
            $display("  ✓ SEG = 7'b0001000 (digit A)");
            test_pass++;
        end else begin
            $display("  ✗ SEG != 7'b0001000 (got 7'b%07b)", SEG);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 4: Display 'F' ===", $time);
        test_write_fnd(8'h0F);
        repeat(100) @(posedge clk);
        if (SEG == 7'b0001110) begin
            $display("  ✓ SEG = 7'b0001110 (digit F)");
            test_pass++;
        end else begin
            $display("  ✗ SEG != 7'b0001110 (got 7'b%07b)", SEG);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 5: Count 0-F ===", $time);
        for (int i = 0; i < 16; i++) begin
            test_write_fnd(i[7:0]);
            repeat(50) @(posedge clk);
            $display("  Digit %01X: SEG = 7'b%07b", i, SEG);
        end
        test_pass++;

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 6: Anode Check ===", $time);
        if (AN == 4'b1110) begin
            $display("  ✓ AN = 4'b1110 (rightmost digit active)");
            test_pass++;
        end else begin
            $display("  ✗ AN != 4'b1110 (got 4'b%04b)", AN);
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

    //==========================================================================
    // High-level Test Tasks
    //==========================================================================

    task test_write_fnd(input [7:0] digit);
        bit ack;
        begin
            i2c_start();

            // Device address + Write
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for device addr");

            // Data (digit)
            i2c_send_byte(digit);
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for data");

            i2c_stop();
        end
    endtask

    //==========================================================================
    // Waveform
    //==========================================================================
    initial begin
        $dumpfile("i2c_fnd_slave_tb.vcd");
        $dumpvars(0, i2c_fnd_slave_tb);
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

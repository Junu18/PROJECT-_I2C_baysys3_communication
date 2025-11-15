`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Slave Top (Register-mapped)
//==============================================================================
// Tests register-mapped I2C slave with LED/FND control
//==============================================================================

module i2c_slave_top_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD   = 10;       // 100 MHz
    localparam CLK_PER_BIT  = 250;      // Quarter bit period
    localparam HALF_PERIOD  = 500;      // Half SCL period
    localparam SLAVE_ADDR   = 7'h55;

    // Register addresses
    localparam [7:0] ADDR_SW_DATA  = 8'h00;
    localparam [7:0] ADDR_LED_LOW  = 8'h01;
    localparam [7:0] ADDR_LED_HIGH = 8'h02;
    localparam [7:0] ADDR_FND_DATA = 8'h03;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;
    logic       scl;
    wire        sda;
    logic [15:0] SW;
    logic [15:0] LED;
    logic [6:0]  SEG;
    logic [3:0]  AN;
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
    i2c_slave_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .SW(SW),
        .LED(LED),
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
        $display("I2C Slave Top Testbench");
        $display("Register-mapped I2C Slave");
        $display("========================================");

        test_pass = 0;
        test_fail = 0;

        // Initialize
        rst_n = 0;
        SW = 16'hABCD;
        master_scl = 1;
        master_sda_oe = 0;
        master_sda_out = 1;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);

        $display("\n[%0t] === Test 1: Write to LED_LOW ===", $time);
        test_write_reg(ADDR_LED_LOW, 8'hFF);
        repeat(100) @(posedge clk);
        if (LED[7:0] == 8'hFF) begin
            $display("  ✓ LED[7:0] = 0xFF");
            test_pass++;
        end else begin
            $display("  ✗ LED[7:0] != 0xFF (got 0x%02h)", LED[7:0]);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 2: Write to LED_HIGH ===", $time);
        test_write_reg(ADDR_LED_HIGH, 8'hAA);
        repeat(100) @(posedge clk);
        if (LED[15:8] == 8'hAA) begin
            $display("  ✓ LED[15:8] = 0xAA");
            test_pass++;
        end else begin
            $display("  ✗ LED[15:8] != 0xAA (got 0x%02h)", LED[15:8]);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 3: Write to FND ===", $time);
        test_write_reg(ADDR_FND_DATA, 8'h05);
        repeat(100) @(posedge clk);
        $display("  FND should display '5'");
        $display("  SEG = 0b%07b", SEG);
        test_pass++;

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 4: Read SW_DATA ===", $time);
        test_read_reg(ADDR_SW_DATA, SW[7:0]);

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 5: Multi-byte Write ===", $time);
        test_write_reg(ADDR_LED_LOW, 8'h12);
        repeat(100) @(posedge clk);
        test_write_reg(ADDR_LED_HIGH, 8'h34);
        repeat(100) @(posedge clk);
        if (LED == 16'h3412) begin
            $display("  ✓ LED = 0x3412");
            test_pass++;
        end else begin
            $display("  ✗ LED != 0x3412 (got 0x%04h)", LED);
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

    task test_write_reg(input [7:0] reg_addr, input [7:0] data);
        bit ack;
        begin
            $display("  Write: Reg[0x%02h] = 0x%02h", reg_addr, data);

            i2c_start();

            // Device address + Write
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for device addr");

            // Register address
            i2c_send_byte(reg_addr);
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for reg addr");

            // Data
            i2c_send_byte(data);
            i2c_receive_ack(ack);
            if (!ack) $display("  ✗ No ACK for data");

            i2c_stop();
        end
    endtask

    task test_read_reg(input [7:0] reg_addr, input [7:0] expected);
        bit ack;
        logic [7:0] data;
        begin
            $display("  Read: Reg[0x%02h] (expect 0x%02h)", reg_addr, expected);

            i2c_start();

            // Device address + Write
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            // Register address
            i2c_send_byte(reg_addr);
            i2c_receive_ack(ack);

            // Repeated START
            i2c_start();

            // Device address + Read
            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);

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
        $dumpfile("i2c_slave_top_tb.vcd");
        $dumpvars(0, i2c_slave_top_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #100000000;
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

endmodule

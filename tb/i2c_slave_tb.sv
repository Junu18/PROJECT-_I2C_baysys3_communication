`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Slave Module
//==============================================================================
// Tests i2c_slave.sv with accurate I2C protocol simulation
// Master simulator matches i2c_master.sv timing (100 kHz SCL)
//==============================================================================

module i2c_slave_tb;

    //==========================================================================
    // Parameters - Match i2c_master.sv timing
    //==========================================================================
    localparam CLK_PERIOD   = 10;       // 100 MHz (10ns)
    localparam CLK_PER_BIT  = 250;      // Quarter bit period (2.5us)
    localparam HALF_PERIOD  = 500;      // Half SCL period (5us)
    localparam BIT_PERIOD   = 1000;     // Full bit period (10us) = 100 kHz
    localparam SLAVE_ADDR   = 7'h55;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;

    // Slave configuration
    logic [6:0] slave_addr;

    // Data interface
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       data_valid;

    // I2C bus
    logic       scl;
    wire        sda;

    // Debug
    logic       debug_addr_match;
    logic       debug_ack_sent;
    logic [1:0] debug_state;
    logic       debug_sda_out;
    logic       debug_sda_oe;

    // Master simulator signals
    logic       master_scl;
    logic       master_sda_oe;
    logic       master_sda_out;

    // Test control
    int         test_pass;
    int         test_fail;
    int         test_number;

    //==========================================================================
    // I2C Bus Assignment
    //==========================================================================
    assign scl = master_scl;
    assign sda = master_sda_oe ? master_sda_out : 1'bz;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    i2c_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(slave_addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .data_valid(data_valid),
        .scl(scl),
        .sda(sda),
        .debug_addr_match(debug_addr_match),
        .debug_ack_sent(debug_ack_sent),
        .debug_state(debug_state),
        .debug_sda_out(debug_sda_out),
        .debug_sda_oe(debug_sda_oe)
    );

    //==========================================================================
    // Clock Generation
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
        $display("I2C Slave Testbench");
        $display("Clock: 100 MHz, I2C: 100 kHz");
        $display("========================================");

        // Initialize
        test_pass = 0;
        test_fail = 0;
        test_number = 0;

        rst_n = 0;
        slave_addr = SLAVE_ADDR;
        tx_data = 8'h00;
        master_scl = 1;
        master_sda_oe = 0;
        master_sda_out = 1;

        // Reset
        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);

        $display("\n[%0t] === Test 1: Write Single Byte ===", $time);
        test_write_single(SLAVE_ADDR, 8'h42);

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 2: Read Single Byte ===", $time);
        tx_data = 8'h5A;
        test_read_single(SLAVE_ADDR, 8'h5A);

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 3: Wrong Address (No Response) ===", $time);
        test_write_single(7'h33, 8'h99);

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 4: Multiple Byte Write ===", $time);
        test_write_multi();

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 5: Multiple Byte Read ===", $time);
        test_read_multi();

        repeat(200) @(posedge clk);

        $display("\n[%0t] === Test 6: Repeated START ===", $time);
        test_repeated_start();

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
    // Master Simulator Tasks - Match i2c_master.sv timing
    //==========================================================================

    // START condition: Matches i2c_master START_1/2/3
    task i2c_start();
        begin
            $display("  [%0t] Master: START", $time);

            // START_1: Both high
            master_sda_oe = 1;
            master_sda_out = 1;
            master_scl = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            // START_2: SDA falls while SCL high
            master_sda_out = 0;
            repeat(HALF_PERIOD) @(posedge clk);

            // START_3: SCL goes low
            master_scl = 0;
            repeat(HALF_PERIOD) @(posedge clk);
        end
    endtask

    // STOP condition: Matches i2c_master STOP_1/2/3
    task i2c_stop();
        begin
            $display("  [%0t] Master: STOP", $time);

            // STOP_1: Both low
            master_sda_oe = 1;
            master_sda_out = 0;
            master_scl = 0;
            repeat(HALF_PERIOD) @(posedge clk);

            // STOP_2: SCL goes high, SDA stays low
            master_scl = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            // STOP_3: SDA rises while SCL high
            master_sda_out = 1;
            repeat(HALF_PERIOD) @(posedge clk);

            // Release bus
            master_sda_oe = 0;
        end
    endtask

    // Send one bit with 4-phase timing
    task i2c_send_bit(input bit value);
        begin
            master_sda_oe = 1;
            master_sda_out = value;

            // SCL_LOW_1
            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_LOW_2
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_1
            master_scl = 1;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_2
            repeat(CLK_PER_BIT) @(posedge clk);
        end
    endtask

    // Send byte (MSB first)
    task i2c_send_byte(input [7:0] data);
        begin
            $display("  [%0t] Master: Sending 0x%02h", $time, data);
            for (int i = 7; i >= 0; i--) begin
                i2c_send_bit(data[i]);
            end
        end
    endtask

    // Receive ACK/NACK
    task i2c_receive_ack(output bit ack);
        begin
            // Release SDA for slave
            master_sda_oe = 0;

            // SCL_LOW_1
            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_LOW_2
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_1 - sample ACK
            master_scl = 1;
            repeat(CLK_PER_BIT/2) @(posedge clk);
            ack = ~sda;  // ACK = 0, NACK = 1
            repeat(CLK_PER_BIT/2) @(posedge clk);

            // SCL_HIGH_2
            repeat(CLK_PER_BIT) @(posedge clk);

            if (ack) begin
                $display("  [%0t] Master: Received ACK", $time);
            end else begin
                $display("  [%0t] Master: Received NACK", $time);
            end
        end
    endtask

    // Send ACK
    task i2c_send_ack();
        begin
            master_sda_oe = 1;
            master_sda_out = 0;  // ACK

            // SCL_LOW_1
            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_LOW_2
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_1
            master_scl = 1;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_2
            repeat(CLK_PER_BIT) @(posedge clk);

            $display("  [%0t] Master: Sent ACK", $time);
        end
    endtask

    // Send NACK
    task i2c_send_nack();
        begin
            master_sda_oe = 1;
            master_sda_out = 1;  // NACK

            // SCL_LOW_1
            master_scl = 0;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_LOW_2
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_1
            master_scl = 1;
            repeat(CLK_PER_BIT) @(posedge clk);

            // SCL_HIGH_2
            repeat(CLK_PER_BIT) @(posedge clk);

            master_sda_oe = 0;  // Release
            $display("  [%0t] Master: Sent NACK", $time);
        end
    endtask

    // Receive byte (MSB first)
    task i2c_receive_byte(output [7:0] data);
        begin
            master_sda_oe = 0;  // Release SDA
            data = 8'h00;

            for (int i = 7; i >= 0; i--) begin
                // SCL_LOW_1
                master_scl = 0;
                repeat(CLK_PER_BIT) @(posedge clk);

                // SCL_LOW_2
                repeat(CLK_PER_BIT) @(posedge clk);

                // SCL_HIGH_1 - sample data
                master_scl = 1;
                repeat(CLK_PER_BIT/2) @(posedge clk);
                data[i] = sda;
                repeat(CLK_PER_BIT/2) @(posedge clk);

                // SCL_HIGH_2
                repeat(CLK_PER_BIT) @(posedge clk);
            end

            $display("  [%0t] Master: Received 0x%02h", $time, data);
        end
    endtask

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Test write single byte
    task test_write_single(input [6:0] addr, input [7:0] data);
        bit ack;
        logic [7:0] received;
        begin
            test_number++;
            $display("  Test %0d: Write 0x%02h to address 0x%02h", test_number, data, addr);

            i2c_start();

            // Send address + write bit
            i2c_send_byte({addr, 1'b0});
            i2c_receive_ack(ack);

            if (addr == SLAVE_ADDR) begin
                // Correct address - expect ACK
                if (ack) begin
                    $display("  ✓ ACK for address");
                    test_pass++;
                end else begin
                    $display("  ✗ Expected ACK for address");
                    test_fail++;
                end

                // Check addr_match
                repeat(10) @(posedge clk);
                if (debug_addr_match) begin
                    $display("  ✓ addr_match asserted");
                    test_pass++;
                end else begin
                    $display("  ✗ addr_match not asserted");
                    test_fail++;
                end

                // Send data
                i2c_send_byte(data);
                i2c_receive_ack(ack);

                if (ack) begin
                    $display("  ✓ ACK for data");
                    test_pass++;
                end else begin
                    $display("  ✗ Expected ACK for data");
                    test_fail++;
                end

                // Check data_valid and rx_data
                repeat(20) @(posedge clk);
                received = rx_data;

                if (received == data) begin
                    $display("  ✓ Data matches: 0x%02h", received);
                    test_pass++;
                end else begin
                    $display("  ✗ Data mismatch: expected 0x%02h, got 0x%02h", data, received);
                    test_fail++;
                end

            end else begin
                // Wrong address - expect NACK
                if (!ack) begin
                    $display("  ✓ Correctly ignored wrong address");
                    test_pass++;
                end else begin
                    $display("  ✗ Should not ACK wrong address");
                    test_fail++;
                end

                if (!debug_addr_match) begin
                    $display("  ✓ addr_match not asserted");
                    test_pass++;
                end else begin
                    $display("  ✗ addr_match should not assert");
                    test_fail++;
                end
            end

            i2c_stop();
        end
    endtask

    // Test read single byte
    task test_read_single(input [6:0] addr, input [7:0] expected);
        bit ack;
        logic [7:0] received;
        begin
            test_number++;
            $display("  Test %0d: Read from address 0x%02h (expect 0x%02h)", test_number, addr, expected);

            i2c_start();

            // Send address + read bit
            i2c_send_byte({addr, 1'b1});
            i2c_receive_ack(ack);

            if (ack) begin
                $display("  ✓ ACK for address");
                test_pass++;
            end else begin
                $display("  ✗ Expected ACK for address");
                test_fail++;
            end

            // Check addr_match
            repeat(10) @(posedge clk);
            if (debug_addr_match) begin
                $display("  ✓ addr_match asserted");
                test_pass++;
            end else begin
                $display("  ✗ addr_match not asserted");
                test_fail++;
            end

            // Receive data
            i2c_receive_byte(received);

            if (received == expected) begin
                $display("  ✓ Data matches: 0x%02h", received);
                test_pass++;
            end else begin
                $display("  ✗ Data mismatch: expected 0x%02h, got 0x%02h", expected, received);
                test_fail++;
            end

            // Send NACK (end of read)
            i2c_send_nack();

            i2c_stop();
        end
    endtask

    // Test multiple byte write
    task test_write_multi();
        bit ack;
        logic [7:0] test_data[3] = '{8'h11, 8'h22, 8'h33};
        begin
            test_number++;
            $display("  Test %0d: Multiple byte write", test_number);

            i2c_start();

            // Send address
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("  ✗ No ACK for address");
                test_fail++;
                i2c_stop();
                return;
            end

            // Send multiple bytes
            foreach(test_data[i]) begin
                $display("  Sending byte %0d: 0x%02h", i, test_data[i]);
                i2c_send_byte(test_data[i]);
                i2c_receive_ack(ack);

                if (ack) begin
                    test_pass++;
                end else begin
                    $display("  ✗ No ACK for byte %0d", i);
                    test_fail++;
                end

                // Verify received data
                repeat(20) @(posedge clk);
                if (rx_data == test_data[i]) begin
                    $display("  ✓ Byte %0d verified", i);
                    test_pass++;
                end else begin
                    $display("  ✗ Byte %0d mismatch", i);
                    test_fail++;
                end
            end

            i2c_stop();
        end
    endtask

    // Test multiple byte read
    task test_read_multi();
        bit ack;
        logic [7:0] test_data[3] = '{8'hAA, 8'hBB, 8'hCC};
        logic [7:0] received;
        begin
            test_number++;
            $display("  Test %0d: Multiple byte read", test_number);

            i2c_start();

            // Send address
            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("  ✗ No ACK for address");
                test_fail++;
                i2c_stop();
                return;
            end

            // Read multiple bytes
            foreach(test_data[i]) begin
                tx_data = test_data[i];
                repeat(100) @(posedge clk);  // Give slave time

                i2c_receive_byte(received);

                if (received == test_data[i]) begin
                    $display("  ✓ Byte %0d: 0x%02h", i, received);
                    test_pass++;
                end else begin
                    $display("  ✗ Byte %0d mismatch", i);
                    test_fail++;
                end

                if (i < 2) begin
                    i2c_send_ack();
                end else begin
                    i2c_send_nack();
                end
            end

            i2c_stop();
        end
    endtask

    // Test repeated START
    task test_repeated_start();
        bit ack;
        logic [7:0] write_val = 8'hAB;
        logic [7:0] read_val;
        begin
            test_number++;
            $display("  Test %0d: Repeated START", test_number);

            // Write phase
            i2c_start();
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            i2c_send_byte(write_val);
            i2c_receive_ack(ack);

            repeat(20) @(posedge clk);
            if (rx_data == write_val) begin
                $display("  ✓ Write phase OK");
                test_pass++;
            end else begin
                $display("  ✗ Write phase failed");
                test_fail++;
            end

            // Repeated START for read
            i2c_start();

            tx_data = 8'hCD;
            repeat(100) @(posedge clk);

            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);

            i2c_receive_byte(read_val);

            if (read_val == 8'hCD) begin
                $display("  ✓ Read phase OK: 0x%02h", read_val);
                test_pass++;
            end else begin
                $display("  ✗ Read phase failed");
                test_fail++;
            end

            i2c_send_nack();
            i2c_stop();
        end
    endtask

    //==========================================================================
    // Monitor
    //==========================================================================
    always @(posedge clk) begin
        if (data_valid) begin
            $display("  [%0t] MONITOR: data_valid=1, rx_data=0x%02h", $time, rx_data);
        end
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_slave_tb.vcd");
        $dumpvars(0, i2c_slave_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #100000000;  // 100ms
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

endmodule

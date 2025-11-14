`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Slave (AXI-compatible interface)
//==============================================================================
// Tests:
// 1. Write operation (address match)
// 2. Read operation
// 3. Wrong address (no response)
// 4. Multiple byte transfers
// 5. Repeated START
//==============================================================================

module i2c_slave_axi_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;      // 100 MHz (10ns period)
    localparam I2C_PERIOD = 10000;   // 100 kHz (10us period)
    localparam SLAVE_ADDR = 7'h55;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;

    // Configuration
    logic [6:0] slave_addr;

    // Data interface
    logic [7:0] tx_data;
    logic [7:0] rx_data;

    // Status
    logic       addr_match;
    logic       ack_sent;
    logic       data_valid;

    // I2C bus
    logic       scl;
    wire        sda;

    // Debug
    logic [1:0] debug_state;
    logic       debug_sda_out;
    logic       debug_sda_oe;

    // Master simulation signals
    logic       master_sda_oe;
    logic       master_sda_out;
    logic       master_scl;

    // Test control
    int         test_pass_count;
    int         test_fail_count;

    //==========================================================================
    // SDA tri-state for master simulation
    //==========================================================================
    assign sda = master_sda_oe ? master_sda_out : 1'bz;
    assign scl = master_scl;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    i2c_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(slave_addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .addr_match(addr_match),
        .ack_sent(ack_sent),
        .data_valid(data_valid),
        .scl(scl),
        .sda(sda),
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
    // Test Stimulus
    //==========================================================================
    initial begin
        $display("========================================");
        $display("I2C Slave AXI Testbench");
        $display("Slave Address: 0x%02h", SLAVE_ADDR);
        $display("========================================");

        // Initialize
        test_pass_count = 0;
        test_fail_count = 0;

        rst_n = 0;
        slave_addr = SLAVE_ADDR;
        tx_data = 8'h00;
        master_scl = 1;
        master_sda_oe = 0;
        master_sda_out = 1;

        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        $display("\n[%0t] === Test 1: Write Single Byte (Address Match) ===", $time);
        test_write(SLAVE_ADDR, 8'h42, "Single byte write");

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 2: Read Single Byte ===", $time);
        tx_data = 8'h5A;
        test_read(SLAVE_ADDR, 8'h5A, "Single byte read");

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 3: Wrong Address (Should Ignore) ===", $time);
        test_write(7'h33, 8'h99, "Wrong address");

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 4: Multiple Byte Write ===", $time);
        test_multi_write();

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 5: Multiple Byte Read ===", $time);
        test_multi_read();

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 6: Write-Read with Repeated START ===", $time);
        test_repeated_start();

        repeat(100) @(posedge clk);

        $display("\n========================================");
        $display("Test Summary:");
        $display("  PASSED: %0d", test_pass_count);
        $display("  FAILED: %0d", test_fail_count);
        $display("========================================");

        if (test_fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end

        $finish;
    end

    //==========================================================================
    // Master Simulation Tasks
    //==========================================================================

    // Generate START condition
    task i2c_start();
        begin
            $display("  [%0t] Master: START", $time);
            master_sda_oe = 1;
            master_sda_out = 1;
            master_scl = 1;
            #(I2C_PERIOD/2);
            master_sda_out = 0;  // SDA falls while SCL high
            #(I2C_PERIOD/2);
            master_scl = 0;
            #(I2C_PERIOD/4);
        end
    endtask

    // Generate STOP condition
    task i2c_stop();
        begin
            $display("  [%0t] Master: STOP", $time);
            master_sda_oe = 1;
            master_sda_out = 0;
            master_scl = 0;
            #(I2C_PERIOD/2);
            master_scl = 1;
            #(I2C_PERIOD/2);
            master_sda_out = 1;  // SDA rises while SCL high
            #(I2C_PERIOD);
            master_sda_oe = 0;   // Release SDA
        end
    endtask

    // Send one bit
    task i2c_send_bit(input bit value);
        begin
            master_sda_oe = 1;
            master_sda_out = value;
            #(I2C_PERIOD/4);
            master_scl = 1;
            #(I2C_PERIOD/2);
            master_scl = 0;
            #(I2C_PERIOD/4);
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
            master_sda_oe = 0;  // Release SDA
            #(I2C_PERIOD/4);
            master_scl = 1;
            #(I2C_PERIOD/4);
            ack = ~sda;  // ACK = 0, NACK = 1
            #(I2C_PERIOD/4);
            master_scl = 0;
            #(I2C_PERIOD/4);
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
            #(I2C_PERIOD/4);
            master_scl = 1;
            #(I2C_PERIOD/2);
            master_scl = 0;
            #(I2C_PERIOD/4);
            $display("  [%0t] Master: Sent ACK", $time);
        end
    endtask

    // Send NACK
    task i2c_send_nack();
        begin
            master_sda_oe = 1;
            master_sda_out = 1;  // NACK
            #(I2C_PERIOD/4);
            master_scl = 1;
            #(I2C_PERIOD/2);
            master_scl = 0;
            #(I2C_PERIOD/4);
            master_sda_oe = 0;
            $display("  [%0t] Master: Sent NACK", $time);
        end
    endtask

    // Receive byte (MSB first)
    task i2c_receive_byte(output [7:0] data);
        begin
            master_sda_oe = 0;  // Release SDA
            data = 8'h00;
            for (int i = 7; i >= 0; i--) begin
                #(I2C_PERIOD/4);
                master_scl = 1;
                #(I2C_PERIOD/4);
                data[i] = sda;
                #(I2C_PERIOD/4);
                master_scl = 0;
                #(I2C_PERIOD/4);
            end
            $display("  [%0t] Master: Received 0x%02h", $time, data);
        end
    endtask

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Test write operation
    task test_write(input [6:0] addr, input [7:0] data, input string test_name);
        bit ack;
        logic [7:0] received_data;
        begin
            $display("  Test: %s", test_name);
            $display("  Writing 0x%02h to address 0x%02h", data, addr);

            i2c_start();

            // Send address + write bit
            i2c_send_byte({addr, 1'b0});
            i2c_receive_ack(ack);

            if (addr == SLAVE_ADDR) begin
                // Correct address
                if (ack) begin
                    $display("  ✓ ACK received for address");
                    test_pass_count++;
                end else begin
                    $display("  ✗ Expected ACK, got NACK");
                    test_fail_count++;
                end

                // Check addr_match
                repeat(5) @(posedge clk);
                if (addr_match) begin
                    $display("  ✓ addr_match asserted");
                    test_pass_count++;
                end else begin
                    $display("  ✗ addr_match not asserted");
                    test_fail_count++;
                end

                // Send data byte
                i2c_send_byte(data);
                i2c_receive_ack(ack);

                if (ack) begin
                    $display("  ✓ ACK received for data");
                    test_pass_count++;
                end else begin
                    $display("  ✗ Expected ACK for data");
                    test_fail_count++;
                end

                // Check data_valid and rx_data
                repeat(10) @(posedge clk);
                if (data_valid) begin
                    $display("  ✓ data_valid asserted");
                    test_pass_count++;

                    received_data = rx_data;
                    if (received_data == data) begin
                        $display("  ✓ Data match: 0x%02h", received_data);
                        test_pass_count++;
                    end else begin
                        $display("  ✗ Data mismatch: expected 0x%02h, got 0x%02h", data, received_data);
                        test_fail_count++;
                    end
                end else begin
                    $display("  ✗ data_valid not asserted");
                    test_fail_count++;
                end
            end else begin
                // Wrong address
                if (!ack) begin
                    $display("  ✓ Correctly ignored wrong address (NACK)");
                    test_pass_count++;
                end else begin
                    $display("  ✗ Should not ACK wrong address");
                    test_fail_count++;
                end

                if (!addr_match) begin
                    $display("  ✓ addr_match correctly not asserted");
                    test_pass_count++;
                end else begin
                    $display("  ✗ addr_match should not be asserted for wrong address");
                    test_fail_count++;
                end
            end

            i2c_stop();
        end
    endtask

    // Test read operation
    task test_read(input [6:0] addr, input [7:0] expected_data, input string test_name);
        bit ack;
        logic [7:0] data_read;
        begin
            $display("  Test: %s", test_name);
            $display("  Reading from address 0x%02h (expect 0x%02h)", addr, expected_data);

            i2c_start();

            // Send address + read bit
            i2c_send_byte({addr, 1'b1});
            i2c_receive_ack(ack);

            if (ack) begin
                $display("  ✓ ACK received for address");
                test_pass_count++;
            end else begin
                $display("  ✗ Expected ACK, got NACK");
                test_fail_count++;
            end

            // Check addr_match
            repeat(5) @(posedge clk);
            if (addr_match) begin
                $display("  ✓ addr_match asserted");
                test_pass_count++;
            end else begin
                $display("  ✗ addr_match not asserted");
                test_fail_count++;
            end

            // Receive data byte
            i2c_receive_byte(data_read);

            if (data_read == expected_data) begin
                $display("  ✓ Data match: 0x%02h", data_read);
                test_pass_count++;
            end else begin
                $display("  ✗ Data mismatch: expected 0x%02h, got 0x%02h", expected_data, data_read);
                test_fail_count++;
            end

            // Send NACK (end of read)
            i2c_send_nack();

            i2c_stop();
        end
    endtask

    // Test multiple byte write
    task test_multi_write();
        bit ack;
        logic [7:0] test_data[3] = '{8'h11, 8'h22, 8'h33};
        begin
            $display("  Test: Multiple byte write");

            i2c_start();

            // Send address
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("  ✗ No ACK for address");
                test_fail_count++;
                i2c_stop();
                return;
            end

            // Send multiple data bytes
            foreach(test_data[i]) begin
                $display("  Sending byte %0d: 0x%02h", i, test_data[i]);
                i2c_send_byte(test_data[i]);
                i2c_receive_ack(ack);

                if (!ack) begin
                    $display("  ✗ No ACK for byte %0d", i);
                    test_fail_count++;
                end else begin
                    test_pass_count++;
                end

                // Check received data
                repeat(10) @(posedge clk);
                if (data_valid && (rx_data == test_data[i])) begin
                    $display("  ✓ Byte %0d received correctly", i);
                    test_pass_count++;
                end else begin
                    $display("  ✗ Byte %0d verification failed", i);
                    test_fail_count++;
                end
            end

            i2c_stop();
        end
    endtask

    // Test multiple byte read
    task test_multi_read();
        bit ack;
        logic [7:0] test_data[3] = '{8'hAA, 8'hBB, 8'hCC};
        logic [7:0] data_read;
        begin
            $display("  Test: Multiple byte read");

            i2c_start();

            // Send address
            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("  ✗ No ACK for address");
                test_fail_count++;
                i2c_stop();
                return;
            end

            // Read multiple bytes
            foreach(test_data[i]) begin
                tx_data = test_data[i];  // Update slave's tx_data
                #(I2C_PERIOD);  // Give slave time to update

                i2c_receive_byte(data_read);

                if (data_read == test_data[i]) begin
                    $display("  ✓ Byte %0d: 0x%02h", i, data_read);
                    test_pass_count++;
                end else begin
                    $display("  ✗ Byte %0d mismatch: expected 0x%02h, got 0x%02h", i, test_data[i], data_read);
                    test_fail_count++;
                end

                if (i < 2) begin
                    i2c_send_ack();  // More bytes to read
                end else begin
                    i2c_send_nack(); // Last byte
                end
            end

            i2c_stop();
        end
    endtask

    // Test repeated START
    task test_repeated_start();
        bit ack;
        logic [7:0] write_data = 8'hAB;
        logic [7:0] read_data;
        begin
            $display("  Test: Write then Read with Repeated START");

            // Write phase
            i2c_start();
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            i2c_send_byte(write_data);
            i2c_receive_ack(ack);

            repeat(10) @(posedge clk);
            if (data_valid && (rx_data == write_data)) begin
                $display("  ✓ Write phase successful");
                test_pass_count++;
            end else begin
                $display("  ✗ Write phase failed");
                test_fail_count++;
            end

            // Repeated START for read
            i2c_start();

            tx_data = 8'hCD;  // Data to be read
            #(I2C_PERIOD);

            i2c_send_byte({SLAVE_ADDR, 1'b1});
            i2c_receive_ack(ack);

            i2c_receive_byte(read_data);

            if (read_data == 8'hCD) begin
                $display("  ✓ Read phase successful: 0x%02h", read_data);
                test_pass_count++;
            end else begin
                $display("  ✗ Read phase failed: expected 0xCD, got 0x%02h", read_data);
                test_fail_count++;
            end

            i2c_send_nack();
            i2c_stop();
        end
    endtask

    //==========================================================================
    // Signal Monitor
    //==========================================================================
    always @(posedge clk) begin
        if (data_valid) begin
            $display("  [%0t] MONITOR: data_valid=1, rx_data=0x%02h", $time, rx_data);
        end
        if (addr_match && !$past(addr_match)) begin
            $display("  [%0t] MONITOR: addr_match asserted", $time);
        end
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_slave_axi_tb.vcd");
        $dumpvars(0, i2c_slave_axi_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

endmodule

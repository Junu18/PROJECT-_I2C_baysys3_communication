`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Slave (AXI-compatible interface)
//==============================================================================
// Tests:
// 1. Write operation (address match)
// 2. Read operation
// 3. Wrong address (no response)
// 4. Multiple byte transfers
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
        $display("========================================");

        // Initialize signals
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

        $display("\n[%0t] === Test 1: Write to Slave (Address Match) ===", $time);
        test_write(SLAVE_ADDR, 8'h42);

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 2: Read from Slave ===", $time);
        tx_data = 8'h5A;  // Data slave will send
        test_read(SLAVE_ADDR);

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 3: Wrong Address (No Response) ===", $time);
        test_write(7'h33, 8'h99);  // Wrong address

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 4: Multiple Byte Write ===", $time);
        test_multi_write();

        repeat(100) @(posedge clk);

        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================");
        $finish;
    end

    //==========================================================================
    // Master Simulation Tasks
    //==========================================================================

    // Generate START condition
    task i2c_start();
        begin
            $display("[%0t] Master: Generating START", $time);
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
            $display("[%0t] Master: Generating STOP", $time);
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
                $display("[%0t] Master: Received ACK", $time);
            end else begin
                $display("[%0t] Master: Received NACK", $time);
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
        end
    endtask

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Test write operation
    task test_write(input [6:0] addr, input [7:0] data);
        bit ack;
        begin
            $display("[%0t] Writing 0x%02h to slave 0x%02h", $time, data, addr);

            i2c_start();

            // Send address + write bit
            i2c_send_byte({addr, 1'b0});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("[%0t] ERROR: No ACK for address", $time);
                i2c_stop();
                return;
            end

            // Check addr_match flag
            if (addr == SLAVE_ADDR) begin
                if (addr_match) begin
                    $display("[%0t] SUCCESS: addr_match asserted", $time);
                end else begin
                    $display("[%0t] ERROR: addr_match not asserted", $time);
                end
            end

            // Send data byte
            i2c_send_byte(data);
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("[%0t] ERROR: No ACK for data", $time);
            end

            // Wait for data_valid
            repeat(10) @(posedge clk);
            if (data_valid) begin
                $display("[%0t] SUCCESS: data_valid asserted, rx_data=0x%02h", $time, rx_data);
                if (rx_data == data) begin
                    $display("[%0t] SUCCESS: Data matches!", $time);
                end else begin
                    $display("[%0t] ERROR: Data mismatch! Expected 0x%02h, got 0x%02h", $time, data, rx_data);
                end
            end else begin
                $display("[%0t] WARNING: data_valid not asserted", $time);
            end

            i2c_stop();
        end
    endtask

    // Test read operation
    task test_read(input [6:0] addr);
        bit ack;
        logic [7:0] data_read;
        begin
            $display("[%0t] Reading from slave 0x%02h", $time, addr);
            $display("[%0t] Slave tx_data = 0x%02h", $time, tx_data);

            i2c_start();

            // Send address + read bit
            i2c_send_byte({addr, 1'b1});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("[%0t] ERROR: No ACK for address", $time);
                i2c_stop();
                return;
            end

            // Check addr_match flag
            if (addr_match) begin
                $display("[%0t] SUCCESS: addr_match asserted", $time);
            end else begin
                $display("[%0t] ERROR: addr_match not asserted", $time);
            end

            // Receive data byte
            i2c_receive_byte(data_read);
            $display("[%0t] Master received: 0x%02h", $time, data_read);

            if (data_read == tx_data) begin
                $display("[%0t] SUCCESS: Data matches slave tx_data!", $time);
            end else begin
                $display("[%0t] ERROR: Data mismatch! Expected 0x%02h, got 0x%02h", $time, tx_data, data_read);
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
            $display("[%0t] Writing multiple bytes to slave", $time);

            i2c_start();

            // Send address
            i2c_send_byte({SLAVE_ADDR, 1'b0});
            i2c_receive_ack(ack);

            if (!ack) begin
                $display("[%0t] ERROR: No ACK for address", $time);
                i2c_stop();
                return;
            end

            // Send multiple data bytes
            foreach(test_data[i]) begin
                $display("[%0t] Sending byte %0d: 0x%02h", $time, i, test_data[i]);
                i2c_send_byte(test_data[i]);
                i2c_receive_ack(ack);

                if (!ack) begin
                    $display("[%0t] ERROR: No ACK for byte %0d", $time, i);
                end

                // Check received data
                repeat(10) @(posedge clk);
                if (data_valid && (rx_data == test_data[i])) begin
                    $display("[%0t] SUCCESS: Byte %0d received correctly", $time, i);
                end else begin
                    $display("[%0t] ERROR: Byte %0d verification failed", $time, i);
                end
            end

            i2c_stop();
        end
    endtask

    //==========================================================================
    // Monitor
    //==========================================================================
    always @(posedge clk) begin
        if (data_valid) begin
            $display("[%0t] MONITOR: data_valid=1, rx_data=0x%02h", $time, rx_data);
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
        #10000000;  // 10ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule

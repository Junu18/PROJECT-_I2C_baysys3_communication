`timescale 1ns / 1ps

//==============================================================================
// Integrated System Testbench for I2C Master + Slave (AXI-compatible)
//==============================================================================
// Tests complete I2C communication between Master and Slave modules
// Both with AXI-compatible interfaces
//==============================================================================

module i2c_system_axi_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz (10ns period)
    localparam SLAVE_ADDR = 7'h55;

    //==========================================================================
    // Common Signals
    //==========================================================================
    logic clk;
    logic reset;
    logic rst_n;

    // I2C Bus
    wire  sda;
    wire  scl;

    //==========================================================================
    // Master Signals
    //==========================================================================
    logic       m_i2c_en;
    logic       m_i2c_start;
    logic       m_i2c_stop;
    logic       m_i2c_rw;
    logic [6:0] m_slave_addr;
    logic [7:0] m_tx_data;
    logic [7:0] m_rx_data;
    logic       m_tx_ready;
    logic       m_tx_done;
    logic       m_rx_done;
    logic       m_busy;
    logic       m_ack_error;

    // Master Debug
    logic       m_debug_busy;
    logic       m_debug_ack;
    logic [3:0] m_debug_state;
    logic       m_debug_scl;
    logic       m_debug_sda_out;
    logic       m_debug_sda_oe;

    //==========================================================================
    // Slave Signals
    //==========================================================================
    logic [6:0] s_slave_addr;
    logic [7:0] s_tx_data;
    logic [7:0] s_rx_data;
    logic       s_addr_match;
    logic       s_ack_sent;
    logic       s_data_valid;

    // Slave Debug
    logic [1:0] s_debug_state;
    logic       s_debug_sda_out;
    logic       s_debug_sda_oe;

    //==========================================================================
    // DUT Instantiation - Master
    //==========================================================================
    i2c_master master (
        .clk(clk),
        .reset(reset),
        .i2c_en(m_i2c_en),
        .i2c_start(m_i2c_start),
        .i2c_stop(m_i2c_stop),
        .i2c_rw(m_i2c_rw),
        .slave_addr(m_slave_addr),
        .tx_data(m_tx_data),
        .rx_data(m_rx_data),
        .tx_ready(m_tx_ready),
        .tx_done(m_tx_done),
        .rx_done(m_rx_done),
        .busy(m_busy),
        .ack_error(m_ack_error),
        .sda(sda),
        .scl(scl),
        .debug_busy(m_debug_busy),
        .debug_ack(m_debug_ack),
        .debug_state(m_debug_state),
        .debug_scl(m_debug_scl),
        .debug_sda_out(m_debug_sda_out),
        .debug_sda_oe(m_debug_sda_oe)
    );

    //==========================================================================
    // DUT Instantiation - Slave
    //==========================================================================
    i2c_slave slave (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(s_slave_addr),
        .tx_data(s_tx_data),
        .rx_data(s_rx_data),
        .addr_match(s_addr_match),
        .ack_sent(s_ack_sent),
        .data_valid(s_data_valid),
        .scl(scl),
        .sda(sda),
        .debug_state(s_debug_state),
        .debug_sda_out(s_debug_sda_out),
        .debug_sda_oe(s_debug_sda_oe)
    );

    //==========================================================================
    // Pull-up resistors on I2C bus
    //==========================================================================
    pullup(sda);
    pullup(scl);

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Reset Assignment
    //==========================================================================
    assign rst_n = ~reset;

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        $display("========================================");
        $display("I2C System Integration Testbench");
        $display("Master + Slave (AXI-compatible)");
        $display("========================================");

        // Initialize signals
        reset = 1;
        m_i2c_en = 0;
        m_i2c_start = 0;
        m_i2c_stop = 0;
        m_i2c_rw = 0;
        m_slave_addr = SLAVE_ADDR;
        m_tx_data = 8'h00;
        s_slave_addr = SLAVE_ADDR;
        s_tx_data = 8'h00;

        // Reset
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(10) @(posedge clk);

        $display("\n[%0t] === Test 1: Master Write, Slave Receive ===", $time);
        test_write_single(8'hA5);

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 2: Master Read, Slave Transmit ===", $time);
        test_read_single(8'h3C);

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 3: Multiple Byte Write ===", $time);
        test_write_multi();

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 4: Write-Read with Repeated START ===", $time);
        test_write_read();

        repeat(100) @(posedge clk);

        $display("\n[%0t] === Test 5: Wrong Address (No Response) ===", $time);
        test_wrong_address();

        repeat(100) @(posedge clk);

        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================");
        $finish;
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Test single byte write
    task test_write_single(input [7:0] data);
        begin
            $display("[%0t] Master writes 0x%02h to slave", $time, data);

            m_tx_data = data;
            m_i2c_rw = 0;  // Write

            // Start transaction
            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            // Wait for master tx_done
            wait(m_tx_done);
            $display("[%0t] Master: tx_done asserted", $time);

            if (m_ack_error) begin
                $display("[%0t] ERROR: Master received NACK!", $time);
            end else begin
                $display("[%0t] SUCCESS: Master received ACK", $time);
            end

            // Check slave received data
            @(posedge clk);
            if (s_data_valid) begin
                $display("[%0t] Slave: data_valid asserted", $time);
                if (s_rx_data == data) begin
                    $display("[%0t] SUCCESS: Slave received correct data (0x%02h)", $time, s_rx_data);
                end else begin
                    $display("[%0t] ERROR: Data mismatch! Expected 0x%02h, got 0x%02h", $time, data, s_rx_data);
                end
            end else begin
                $display("[%0t] WARNING: Slave data_valid not asserted", $time);
            end

            // Send STOP
            @(posedge clk);
            m_i2c_stop = 1;
            @(posedge clk);
            m_i2c_stop = 0;

            // Wait for idle
            wait(!m_busy);
            $display("[%0t] Transaction complete", $time);
        end
    endtask

    // Test single byte read
    task test_read_single(input [7:0] data);
        begin
            $display("[%0t] Master reads from slave (expects 0x%02h)", $time, data);

            s_tx_data = data;  // Slave prepares data
            m_i2c_rw = 1;      // Read

            // Start transaction
            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            // Wait for master rx_done
            wait(m_rx_done);
            $display("[%0t] Master: rx_done asserted", $time);

            if (m_ack_error) begin
                $display("[%0t] ERROR: Master received NACK!", $time);
            end else begin
                $display("[%0t] SUCCESS: Master received ACK", $time);
            end

            // Check master received data
            if (m_rx_data == data) begin
                $display("[%0t] SUCCESS: Master received correct data (0x%02h)", $time, m_rx_data);
            end else begin
                $display("[%0t] ERROR: Data mismatch! Expected 0x%02h, got 0x%02h", $time, data, m_rx_data);
            end

            // Send STOP
            @(posedge clk);
            m_i2c_stop = 1;
            @(posedge clk);
            m_i2c_stop = 0;

            // Wait for idle
            wait(!m_busy);
            $display("[%0t] Transaction complete", $time);
        end
    endtask

    // Test multiple byte write
    task test_write_multi();
        logic [7:0] test_data[3] = '{8'h11, 8'h22, 8'h33};
        begin
            $display("[%0t] Master writes multiple bytes", $time);

            m_i2c_rw = 0;  // Write

            // Start first byte
            m_tx_data = test_data[0];
            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            wait(m_tx_done);
            $display("[%0t] Byte 1 (0x%02h) sent", $time, test_data[0]);

            // Check slave received
            if (s_data_valid && (s_rx_data == test_data[0])) begin
                $display("[%0t] SUCCESS: Slave received byte 1", $time);
            end

            // Send byte 2
            m_tx_data = test_data[1];
            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            wait(m_tx_done);
            $display("[%0t] Byte 2 (0x%02h) sent", $time, test_data[1]);

            // Check slave received
            @(posedge clk);
            if (s_data_valid && (s_rx_data == test_data[1])) begin
                $display("[%0t] SUCCESS: Slave received byte 2", $time);
            end

            // Send byte 3
            m_tx_data = test_data[2];
            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            wait(m_tx_done);
            $display("[%0t] Byte 3 (0x%02h) sent", $time, test_data[2]);

            // Check slave received
            @(posedge clk);
            if (s_data_valid && (s_rx_data == test_data[2])) begin
                $display("[%0t] SUCCESS: Slave received byte 3", $time);
            end

            // Send STOP
            @(posedge clk);
            m_i2c_stop = 1;
            @(posedge clk);
            m_i2c_stop = 0;

            wait(!m_busy);
            $display("[%0t] Multi-byte write complete", $time);
        end
    endtask

    // Test write then read with repeated START
    task test_write_read();
        logic [7:0] write_data = 8'hAB;
        logic [7:0] read_data = 8'hCD;
        begin
            $display("[%0t] Write 0x%02h then Read (expects 0x%02h)", $time, write_data, read_data);

            // Write phase
            m_tx_data = write_data;
            m_i2c_rw = 0;  // Write

            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            wait(m_tx_done);
            $display("[%0t] Write phase complete", $time);

            // Check slave received
            @(posedge clk);
            if (s_data_valid && (s_rx_data == write_data)) begin
                $display("[%0t] SUCCESS: Slave received write data", $time);
            end

            // Prepare slave for read
            s_tx_data = read_data;

            // Repeated START for read
            m_i2c_rw = 1;  // Read

            @(posedge clk);
            m_i2c_start = 1;
            @(posedge clk);
            m_i2c_start = 0;

            wait(m_rx_done);
            $display("[%0t] Read phase complete", $time);

            // Check master received
            if (m_rx_data == read_data) begin
                $display("[%0t] SUCCESS: Master received correct read data (0x%02h)", $time, m_rx_data);
            end else begin
                $display("[%0t] ERROR: Read data mismatch! Expected 0x%02h, got 0x%02h", $time, read_data, m_rx_data);
            end

            // Send STOP
            @(posedge clk);
            m_i2c_stop = 1;
            @(posedge clk);
            m_i2c_stop = 0;

            wait(!m_busy);
            $display("[%0t] Write-Read test complete", $time);
        end
    endtask

    // Test wrong address
    task test_wrong_address();
        logic [6:0] wrong_addr = 7'h33;
        begin
            $display("[%0t] Attempting write to wrong address 0x%02h", $time, wrong_addr);

            m_slave_addr = wrong_addr;  // Wrong address
            m_tx_data = 8'h99;
            m_i2c_rw = 0;  // Write

            @(posedge clk);
            m_i2c_en = 1;
            @(posedge clk);
            m_i2c_en = 0;

            // Wait a reasonable time for ACK
            repeat(20000) @(posedge clk);

            if (m_ack_error) begin
                $display("[%0t] SUCCESS: Master correctly detected NACK", $time);
            end else begin
                $display("[%0t] WARNING: ack_error not asserted", $time);
            end

            if (!s_addr_match) begin
                $display("[%0t] SUCCESS: Slave correctly ignored wrong address", $time);
            end else begin
                $display("[%0t] ERROR: Slave incorrectly matched wrong address", $time);
            end

            // Send STOP anyway
            @(posedge clk);
            m_i2c_stop = 1;
            @(posedge clk);
            m_i2c_stop = 0;

            wait(!m_busy);

            // Restore correct address
            m_slave_addr = SLAVE_ADDR;
            $display("[%0t] Wrong address test complete", $time);
        end
    endtask

    //==========================================================================
    // Monitors
    //==========================================================================
    always @(posedge clk) begin
        if (m_tx_done) begin
            $display("[%0t] MONITOR: Master tx_done, ack_error=%b", $time, m_ack_error);
        end
        if (m_rx_done) begin
            $display("[%0t] MONITOR: Master rx_done, rx_data=0x%02h", $time, m_rx_data);
        end
        if (s_data_valid) begin
            $display("[%0t] MONITOR: Slave data_valid, rx_data=0x%02h", $time, s_rx_data);
        end
        if (s_addr_match) begin
            $display("[%0t] MONITOR: Slave addr_match asserted", $time);
        end
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_system_axi_tb.vcd");
        $dumpvars(0, i2c_system_axi_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #100000000;  // 100ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule

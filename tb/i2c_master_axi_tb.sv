`timescale 1ns / 1ps

//==============================================================================
// Testbench for I2C Master (AXI-compatible interface)
//==============================================================================
// Tests:
// 1. Single byte write operation
// 2. Single byte read operation
// 3. Multiple byte write operation
// 4. Repeated START condition
//==============================================================================

module i2c_master_axi_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz (10ns period)
    localparam SLAVE_ADDR = 7'h55;

    //==========================================================================
    // Signals
    //==========================================================================
    logic       clk;
    logic       reset;

    // Control signals
    logic       i2c_en;
    logic       i2c_start;
    logic       i2c_stop;
    logic       i2c_rw;

    // Data signals
    logic [6:0] slave_addr;
    logic [7:0] tx_data;
    logic [7:0] rx_data;

    // Status signals
    logic       tx_ready;
    logic       tx_done;
    logic       rx_done;
    logic       busy;
    logic       ack_error;

    // I2C bus
    wire        sda;
    wire        scl;

    // Debug
    logic       debug_busy;
    logic       debug_ack;
    logic [3:0] debug_state;
    logic       debug_scl;
    logic       debug_sda_out;
    logic       debug_sda_oe;

    // Slave simulation signals
    logic       slave_sda_oe;
    logic       slave_sda_out;
    logic [7:0] slave_tx_byte;  // Data slave will send

    //==========================================================================
    // SDA tri-state for slave simulation
    //==========================================================================
    assign sda = slave_sda_oe ? slave_sda_out : 1'bz;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    i2c_master dut (
        .clk(clk),
        .reset(reset),
        .i2c_en(i2c_en),
        .i2c_start(i2c_start),
        .i2c_stop(i2c_stop),
        .i2c_rw(i2c_rw),
        .slave_addr(slave_addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .tx_ready(tx_ready),
        .tx_done(tx_done),
        .rx_done(rx_done),
        .busy(busy),
        .ack_error(ack_error),
        .sda(sda),
        .scl(scl),
        .debug_busy(debug_busy),
        .debug_ack(debug_ack),
        .debug_state(debug_state),
        .debug_scl(debug_scl),
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
    // Simple I2C Slave Model
    //==========================================================================
    logic [7:0] slave_addr_received;
    logic [7:0] slave_data_received;
    logic       slave_rw_bit;
    int         slave_bit_count;

    initial begin
        slave_sda_oe = 0;
        slave_sda_out = 1;
        slave_tx_byte = 8'hA5;  // Default slave response data
        slave_bit_count = 0;

        forever begin
            @(posedge scl or negedge scl or posedge sda or negedge sda);

            // Detect START: SDA falls while SCL high
            if (scl === 1'b1 && $fell(sda)) begin
                $display("[%0t] SLAVE: START detected", $time);
                slave_bit_count = 0;
                slave_addr_received = 0;
                slave_data_received = 0;
            end

            // Detect STOP: SDA rises while SCL high
            if (scl === 1'b1 && $rose(sda)) begin
                $display("[%0t] SLAVE: STOP detected", $time);
                slave_sda_oe = 0;
            end

            // Sample on SCL rising edge
            if ($rose(scl)) begin
                if (slave_bit_count < 8) begin
                    // Receive address or data
                    if (slave_bit_count < 8) begin
                        slave_addr_received = {slave_addr_received[6:0], sda};
                    end
                    slave_bit_count++;
                end else if (slave_bit_count == 8) begin
                    // ACK bit - slave drives SDA low
                    slave_bit_count++;
                end else if (slave_bit_count >= 9 && slave_bit_count < 17) begin
                    // Data byte
                    slave_data_received = {slave_data_received[6:0], sda};
                    slave_bit_count++;
                end
            end

            // Drive on SCL falling edge
            if ($fell(scl)) begin
                if (slave_bit_count == 8) begin
                    // Send ACK
                    slave_sda_oe = 1;
                    slave_sda_out = 0;
                    $display("[%0t] SLAVE: Sending ACK for addr=0x%02h", $time, slave_addr_received);
                    slave_rw_bit = slave_addr_received[0];
                end else if (slave_bit_count == 9) begin
                    slave_sda_oe = 0;
                    slave_sda_out = 1;

                    if (slave_rw_bit == 1'b1) begin
                        // Read operation - prepare to send data
                        slave_bit_count = 0;  // Reset for data phase
                    end else begin
                        // Write operation - prepare to receive data
                        slave_bit_count = 9;
                    end
                end else if (slave_rw_bit == 1'b1 && slave_bit_count < 8) begin
                    // Master reading - slave sends data
                    slave_sda_oe = 1;
                    slave_sda_out = slave_tx_byte[7 - slave_bit_count];
                end else if (slave_bit_count == 17) begin
                    // Send ACK for data byte
                    slave_sda_oe = 1;
                    slave_sda_out = 0;
                    $display("[%0t] SLAVE: Received data=0x%02h, sending ACK", $time, slave_data_received);
                end else if (slave_bit_count == 18) begin
                    slave_sda_oe = 0;
                    slave_sda_out = 1;
                end
            end
        end
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        $display("========================================");
        $display("I2C Master AXI Testbench");
        $display("========================================");

        // Initialize signals
        reset = 1;
        i2c_en = 0;
        i2c_start = 0;
        i2c_stop = 0;
        i2c_rw = 0;
        slave_addr = SLAVE_ADDR;
        tx_data = 8'h00;

        // Reset
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);

        $display("\n[%0t] === Test 1: Single Byte Write ===", $time);
        test_single_write(8'h42);

        repeat(50) @(posedge clk);

        $display("\n[%0t] === Test 2: Single Byte Read ===", $time);
        slave_tx_byte = 8'h5A;
        test_single_read();

        repeat(50) @(posedge clk);

        $display("\n[%0t] === Test 3: Multiple Byte Write ===", $time);
        test_multi_write();

        repeat(50) @(posedge clk);

        $display("\n[%0t] === Test 4: Repeated START ===", $time);
        test_repeated_start();

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
    task test_single_write(input [7:0] data);
        begin
            $display("[%0t] Writing 0x%02h to slave 0x%02h", $time, data, SLAVE_ADDR);

            // Set up write operation
            tx_data = data;
            i2c_rw = 0;  // Write

            // Start transaction
            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            // Wait for tx_done
            wait(tx_done);
            $display("[%0t] Write complete, tx_done asserted", $time);

            if (ack_error) begin
                $display("[%0t] ERROR: NACK received!", $time);
            end else begin
                $display("[%0t] SUCCESS: ACK received", $time);
            end

            // Send STOP
            @(posedge clk);
            i2c_stop = 1;
            @(posedge clk);
            i2c_stop = 0;

            // Wait for IDLE
            wait(!busy);
            $display("[%0t] Transaction complete, back to IDLE", $time);
        end
    endtask

    // Test single byte read
    task test_single_read();
        begin
            $display("[%0t] Reading from slave 0x%02h", $time, SLAVE_ADDR);

            // Set up read operation
            i2c_rw = 1;  // Read

            // Start transaction
            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            // Wait for rx_done
            wait(rx_done);
            $display("[%0t] Read complete, rx_done asserted", $time);
            $display("[%0t] Received data: 0x%02h", $time, rx_data);

            if (ack_error) begin
                $display("[%0t] ERROR: NACK received!", $time);
            end else begin
                $display("[%0t] SUCCESS: ACK received", $time);
            end

            // Send STOP
            @(posedge clk);
            i2c_stop = 1;
            @(posedge clk);
            i2c_stop = 0;

            // Wait for IDLE
            wait(!busy);
            $display("[%0t] Transaction complete, back to IDLE", $time);
        end
    endtask

    // Test multiple byte write
    task test_multi_write();
        begin
            $display("[%0t] Writing multiple bytes to slave", $time);

            // First byte
            tx_data = 8'h11;
            i2c_rw = 0;  // Write

            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            wait(tx_done);
            $display("[%0t] Byte 1 (0x11) sent", $time);

            // Second byte
            tx_data = 8'h22;
            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            wait(tx_done);
            $display("[%0t] Byte 2 (0x22) sent", $time);

            // Third byte
            tx_data = 8'h33;
            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            wait(tx_done);
            $display("[%0t] Byte 3 (0x33) sent", $time);

            // Send STOP
            @(posedge clk);
            i2c_stop = 1;
            @(posedge clk);
            i2c_stop = 0;

            wait(!busy);
            $display("[%0t] Multi-byte write complete", $time);
        end
    endtask

    // Test repeated START
    task test_repeated_start();
        begin
            $display("[%0t] Testing repeated START (Write then Read)", $time);

            // First: Write operation
            tx_data = 8'hAB;
            i2c_rw = 0;  // Write

            @(posedge clk);
            i2c_en = 1;
            @(posedge clk);
            i2c_en = 0;

            wait(tx_done);
            $display("[%0t] Write phase done", $time);

            // Repeated START for Read
            slave_tx_byte = 8'hCD;
            i2c_rw = 1;  // Read

            @(posedge clk);
            i2c_start = 1;
            @(posedge clk);
            i2c_start = 0;

            wait(rx_done);
            $display("[%0t] Read phase done, data=0x%02h", $time, rx_data);

            // Send STOP
            @(posedge clk);
            i2c_stop = 1;
            @(posedge clk);
            i2c_stop = 0;

            wait(!busy);
            $display("[%0t] Repeated START test complete", $time);
        end
    endtask

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_master_axi_tb.vcd");
        $dumpvars(0, i2c_master_axi_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule

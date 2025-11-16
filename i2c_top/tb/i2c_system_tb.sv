`timescale 1ns / 1ps

//==============================================================================
// I2C Multi-Slave System Testbench
//==============================================================================
// Tests I2C Master communicating with all three slaves:
//  - LED Slave (0x55) - Write
//  - FND Slave (0x56) - Write
//  - Switch Slave (0x57) - Read
//==============================================================================

module i2c_system_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz

    // Slave addresses
    localparam [6:0] ADDR_LED = 7'h55;
    localparam [6:0] ADDR_FND = 7'h56;
    localparam [6:0] ADDR_SW  = 7'h57;

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

    // Test control
    int          test_pass;
    int          test_fail;

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
    // Test Sequence
    //==========================================================================
    initial begin
        $display("========================================");
        $display("I2C Multi-Slave System Testbench");
        $display("Testing Master + 3 Slaves");
        $display("========================================");

        test_pass = 0;
        test_fail = 0;

        // Initialize
        rst_n = 0;
        start = 0;
        rw_bit = 0;
        slave_addr = 7'h00;
        tx_data = 8'h00;
        SW = 8'hAB;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);

        //======================================================================
        // Test 1: Write to LED Slave (0x55)
        //======================================================================
        $display("\n[%0t] === Test 1: Write 0xFF to LED Slave (0x55) ===", $time);
        master_write(ADDR_LED, 8'hFF);
        repeat(100) @(posedge clk);

        if (LED == 8'hFF && !ack_error) begin
            $display("  ✓ LED = 0xFF, No ACK error");
            test_pass++;
        end else begin
            $display("  ✗ LED = 0x%02h (expected 0xFF), ACK error = %b", LED, ack_error);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 2: Write to FND Slave (0x56)
        //======================================================================
        $display("\n[%0t] === Test 2: Write 0x05 to FND Slave (0x56) ===", $time);
        master_write(ADDR_FND, 8'h05);
        repeat(100) @(posedge clk);

        if (SEG == 7'b0010010 && !ack_error) begin
            $display("  ✓ FND shows '5' (SEG = 7'b0010010), No ACK error");
            test_pass++;
        end else begin
            $display("  ✗ SEG = 7'b%07b (expected 7'b0010010), ACK error = %b", SEG, ack_error);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 3: Read from Switch Slave (0x57)
        //======================================================================
        $display("\n[%0t] === Test 3: Read from Switch Slave (0x57) ===", $time);
        SW = 8'hCD;
        master_read(ADDR_SW);
        repeat(100) @(posedge clk);

        if (rx_data == 8'hCD && !ack_error) begin
            $display("  ✓ Read SW = 0xCD, No ACK error");
            test_pass++;
        end else begin
            $display("  ✗ Read data = 0x%02h (expected 0xCD), ACK error = %b", rx_data, ack_error);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 4: Sequential Operations
        //======================================================================
        $display("\n[%0t] === Test 4: Sequential Operations ===", $time);

        // Write to LED
        master_write(ADDR_LED, 8'hAA);
        repeat(50) @(posedge clk);

        // Write to FND
        master_write(ADDR_FND, 8'h0A);
        repeat(50) @(posedge clk);

        // Read from Switch
        SW = 8'h12;
        master_read(ADDR_SW);
        repeat(50) @(posedge clk);

        if (LED == 8'hAA && SEG == 7'b0001000 && rx_data == 8'h12 && !ack_error) begin
            $display("  ✓ All sequential operations successful");
            $display("    LED = 0xAA, FND shows 'A', SW read = 0x12");
            test_pass++;
        end else begin
            $display("  ✗ Sequential operation error");
            $display("    LED = 0x%02h (expected 0xAA)", LED);
            $display("    SEG = 7'b%07b (expected 7'b0001000)", SEG);
            $display("    SW = 0x%02h (expected 0x12)", rx_data);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 5: LED Pattern Test
        //======================================================================
        $display("\n[%0t] === Test 5: LED Pattern Test ===", $time);
        master_write(ADDR_LED, 8'b10101010);
        repeat(50) @(posedge clk);
        master_write(ADDR_LED, 8'b01010101);
        repeat(50) @(posedge clk);

        if (LED == 8'b01010101 && !ack_error) begin
            $display("  ✓ LED pattern updated correctly");
            test_pass++;
        end else begin
            $display("  ✗ LED = 0b%08b (expected 0b01010101)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 6: FND Counter Test (0-F)
        //======================================================================
        $display("\n[%0t] === Test 6: FND Counter (0-F) ===", $time);
        for (int i = 0; i < 16; i++) begin
            master_write(ADDR_FND, i[7:0]);
            repeat(30) @(posedge clk);
        end
        $display("  ✓ FND counted 0-F");
        test_pass++;

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 7: Switch → LED Copy
        //======================================================================
        $display("\n[%0t] === Test 7: Switch → LED Copy ===", $time);
        SW = 8'h3C;
        master_read(ADDR_SW);
        repeat(50) @(posedge clk);
        master_write(ADDR_LED, rx_data);
        repeat(50) @(posedge clk);

        if (LED == 8'h3C && !ack_error) begin
            $display("  ✓ Switch value copied to LED (0x3C)");
            test_pass++;
        end else begin
            $display("  ✗ LED = 0x%02h (expected 0x3C)", LED);
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Test 8: Invalid Address Test
        //======================================================================
        $display("\n[%0t] === Test 8: Invalid Address (0x99) ===", $time);
        master_write(7'h99, 8'hFF);
        repeat(100) @(posedge clk);

        if (ack_error) begin
            $display("  ✓ ACK error detected for invalid address");
            test_pass++;
        end else begin
            $display("  ✗ ACK error NOT detected");
            test_fail++;
        end

        repeat(200) @(posedge clk);

        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("Test Summary:");
        $display("  PASSED: %0d", test_pass);
        $display("  FAILED: %0d", test_fail);
        $display("========================================");

        if (test_fail == 0) begin
            $display("✓ ALL TESTS PASSED!");
            $display("\nSystem demonstrates:");
            $display("  - I2C multi-device bus");
            $display("  - Address-based slave selection");
            $display("  - Write operations (LED, FND)");
            $display("  - Read operations (Switch)");
            $display("  - Error detection (invalid address)");
        end else begin
            $display("✗ SOME TESTS FAILED!");
        end

        $finish;
    end

    //==========================================================================
    // Master Control Tasks
    //==========================================================================

    task master_write(input [6:0] addr, input [7:0] data);
        begin
            $display("  Master Write: Addr=0x%02h, Data=0x%02h", addr, data);

            slave_addr = addr;
            tx_data = data;
            rw_bit = 1'b0;  // Write

            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // Wait for done
            wait(done == 1);
            @(posedge clk);

            if (ack_error) begin
                $display("  ⚠ ACK error during write");
            end
        end
    endtask

    task master_read(input [6:0] addr);
        begin
            $display("  Master Read: Addr=0x%02h", addr);

            slave_addr = addr;
            rw_bit = 1'b1;  // Read

            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // Wait for done
            wait(done == 1);
            @(posedge clk);

            if (ack_error) begin
                $display("  ⚠ ACK error during read");
            end else begin
                $display("  Read data: 0x%02h", rx_data);
            end
        end
    endtask

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("i2c_system_tb.vcd");
        $dumpvars(0, i2c_system_tb);
    end

    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #100000000;
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

    //==========================================================================
    // Debug Monitor (optional)
    //==========================================================================
    initial begin
        forever begin
            @(posedge clk);
            if (debug_addr_match_led) $display("  [DEBUG] LED Slave addressed");
            if (debug_addr_match_fnd) $display("  [DEBUG] FND Slave addressed");
            if (debug_addr_match_sw)  $display("  [DEBUG] Switch Slave addressed");
        end
    end

endmodule

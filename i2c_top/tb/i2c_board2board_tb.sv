//==============================================================================
// Board-to-Board I2C Communication Testbench
// Tests communication between Master Board and Slave Board
// Simulates real PMOD connection scenario
//==============================================================================

`timescale 1ns / 1ps

module i2c_board2board_tb;

    //==========================================================================
    // Common signals
    //==========================================================================
    logic clk;
    logic rst_n;

    //==========================================================================
    // Master Board signals
    //==========================================================================
    logic        master_start;
    logic [6:0]  master_slave_addr;
    logic        master_rw_bit;
    logic [7:0]  master_tx_data;
    logic        master_busy;
    logic        master_done;
    logic        master_ack_error;
    logic [7:0]  master_rx_data;

    //==========================================================================
    // Slave Board signals
    //==========================================================================
    logic [7:0]  slave_sw;
    logic [7:0]  slave_led;
    logic [6:0]  slave_seg;
    logic [3:0]  slave_an;

    //==========================================================================
    // I2C Bus (with pull-up resistors on PMOD cable)
    //==========================================================================
    tri1 sda;  // Pull-up via 4.7kΩ resistor
    tri1 scl;  // Pull-up via 4.7kΩ resistor

    //==========================================================================
    // Master Board Instance (Board 1)
    //==========================================================================
    i2c_master_board u_master_board (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (master_start),
        .slave_addr (master_slave_addr),
        .rw_bit     (master_rw_bit),
        .tx_data    (master_tx_data),
        .busy       (master_busy),
        .done       (master_done),
        .ack_error  (master_ack_error),
        .rx_data    (master_rx_data),
        .sda        (sda),
        .scl        (scl)
    );

    //==========================================================================
    // Slave Board Instance (Board 2)
    //==========================================================================
    i2c_slave_board u_slave_board (
        .clk   (clk),
        .rst_n (rst_n),
        .SW    (slave_sw),
        .LED   (slave_led),
        .SEG   (slave_seg),
        .AN    (slave_an),
        .sda   (sda),
        .scl   (scl)
    );

    //==========================================================================
    // Clock generation (100 MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================================
    // Test result tracking
    //==========================================================================
    int pass_count = 0;
    int fail_count = 0;

    //==========================================================================
    // Test tasks
    //==========================================================================
    task automatic master_write(input logic [6:0] addr, input logic [7:0] data);
        master_slave_addr = addr;
        master_rw_bit     = 1'b0;  // Write
        master_tx_data    = data;
        master_start      = 1'b1;
        @(posedge clk);
        master_start      = 1'b0;
        wait(master_done);
        repeat(10) @(posedge clk);
    endtask

    task automatic master_read(input logic [6:0] addr);
        master_slave_addr = addr;
        master_rw_bit     = 1'b1;  // Read
        master_start      = 1'b1;
        @(posedge clk);
        master_start      = 1'b0;
        wait(master_done);
        repeat(10) @(posedge clk);
    endtask

    //==========================================================================
    // Test execution
    //==========================================================================
    initial begin
        // VCD dump for waveform analysis
        $dumpfile("i2c_board2board_tb.vcd");
        $dumpvars(0, i2c_board2board_tb);

        // Initialize
        rst_n             = 0;
        master_start      = 0;
        master_slave_addr = 0;
        master_rw_bit     = 0;
        master_tx_data    = 0;
        slave_sw          = 8'hCD;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        $display("================================================================================");
        $display("          BOARD-TO-BOARD I2C COMMUNICATION TEST");
        $display("          Master Board <--PMOD--> Slave Board");
        $display("================================================================================");
        $display("");

        //======================================================================
        // Test 1: Write to LED Slave (0x55)
        //======================================================================
        $display("Test 1: Master writes 0xFF to LED Slave (0x55)");
        master_write(7'h55, 8'hFF);
        if (slave_led == 8'hFF && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (LED=0x%0h, expected=0xFF, ack_error=%0b)\n", slave_led, master_ack_error); end

        //======================================================================
        // Test 2: Write to FND Slave (0x56)
        //======================================================================
        $display("Test 2: Master writes 0x05 to FND Slave (0x56)");
        master_write(7'h56, 8'h05);
        if (slave_seg == 7'b0010010 && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (SEG=0b%07b, expected=0b0010010, ack_error=%0b)\n", slave_seg, master_ack_error); end

        //======================================================================
        // Test 3: Read from Switch Slave (0x57)
        //======================================================================
        $display("Test 3: Master reads from Switch Slave (0x57), SW=0xCD");
        slave_sw = 8'hCD;
        repeat(5) @(posedge clk);
        master_read(7'h57);
        if (master_rx_data == 8'hCD && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (rx_data=0x%0h, expected=0xCD, ack_error=%0b)\n", master_rx_data, master_ack_error); end

        //======================================================================
        // Test 4: Sequential Operations
        //======================================================================
        $display("Test 4: Sequential - LED write → FND write → Switch read");
        master_write(7'h55, 8'hAA);
        master_write(7'h56, 8'h0F);
        slave_sw = 8'h12;
        repeat(5) @(posedge clk);
        master_read(7'h57);
        if (slave_led == 8'hAA && slave_seg == 7'b0001000 && master_rx_data == 8'h12 && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (LED=0x%0h, SEG=0b%07b, rx_data=0x%0h, ack_error=%0b)\n",
                                          slave_led, slave_seg, master_rx_data, master_ack_error); end

        //======================================================================
        // Test 5: LED Pattern Test
        //======================================================================
        $display("Test 5: LED Pattern - 0xAA → 0x55");
        master_write(7'h55, 8'hAA);
        if (slave_led != 8'hAA) begin fail_count++; $display("  ✗ FAIL (step 1)\n"); end
        master_write(7'h55, 8'h55);
        if (slave_led == 8'h55 && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (LED=0x%0h, expected=0x55, ack_error=%0b)\n", slave_led, master_ack_error); end

        //======================================================================
        // Test 6: FND Counter (0-F)
        //======================================================================
        $display("Test 6: FND Counter (0 → F)");
        for (int i = 0; i < 16; i++) begin
            master_write(7'h56, i);
        end
        if (slave_seg == 7'b0001000 && !master_ack_error)  // F = 0b0001000
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (SEG=0b%07b, expected=0b0001000)\n", slave_seg); end

        //======================================================================
        // Test 7: Switch → LED Copy
        //======================================================================
        $display("Test 7: Read Switch (0x3C) → Write to LED");
        slave_sw = 8'h3C;
        repeat(5) @(posedge clk);
        master_read(7'h57);
        master_write(7'h55, master_rx_data);
        if (slave_led == 8'h3C && master_rx_data == 8'h3C && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (LED=0x%0h, rx_data=0x%0h, expected=0x3C)\n", slave_led, master_rx_data); end

        //======================================================================
        // Test 8: Invalid Address (0x99)
        //======================================================================
        $display("Test 8: Write to invalid address (0x99)");
        master_write(7'h99, 8'hFF);
        if (master_ack_error)
            begin pass_count++; $display("  ✓ PASS (ACK error detected)\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (no ACK error)\n"); end

        //======================================================================
        // Test 9: Continuous Read (5 times)
        //======================================================================
        $display("Test 9: Continuous Read from Switch (5x)");
        slave_sw = 8'hA5;
        repeat(5) @(posedge clk);
        for (int i = 0; i < 5; i++) begin
            master_read(7'h57);
            if (master_rx_data != 8'hA5 || master_ack_error) begin
                fail_count++;
                $display("  ✗ FAIL (iteration %0d, rx_data=0x%0h, expected=0xA5)\n", i, master_rx_data);
                break;
            end
            if (i == 4) begin
                pass_count++;
                $display("  ✓ PASS (5 consecutive reads successful)\n");
            end
        end

        //======================================================================
        // Test 10: Write → Immediate Read (minimal delay)
        //======================================================================
        $display("Test 10: Write LED → Immediate Read Switch");
        master_write(7'h55, 8'h33);
        @(posedge clk);  // Minimal delay
        slave_sw = 8'h77;
        repeat(5) @(posedge clk);
        master_read(7'h57);
        if (slave_led == 8'h33 && master_rx_data == 8'h77 && !master_ack_error)
            begin pass_count++; $display("  ✓ PASS\n"); end
        else
            begin fail_count++; $display("  ✗ FAIL (LED=0x%0h, rx_data=0x%0h)\n", slave_led, master_rx_data); end

        //======================================================================
        // Test 11: Bit Pattern Stress Test
        //======================================================================
        $display("Test 11: Bit Patterns (0x00, 0xFF, 0xAA, 0x55)");
        master_write(7'h55, 8'h00);
        if (slave_led != 8'h00) begin fail_count++; $display("  ✗ FAIL (0x00)\n"); end
        else begin
            master_write(7'h55, 8'hFF);
            if (slave_led != 8'hFF) begin fail_count++; $display("  ✗ FAIL (0xFF)\n"); end
            else begin
                master_write(7'h55, 8'hAA);
                if (slave_led != 8'hAA) begin fail_count++; $display("  ✗ FAIL (0xAA)\n"); end
                else begin
                    master_write(7'h55, 8'h55);
                    if (slave_led == 8'h55 && !master_ack_error)
                        begin pass_count++; $display("  ✓ PASS\n"); end
                    else
                        begin fail_count++; $display("  ✗ FAIL (0x55, LED=0x%0h)\n", slave_led); end
                end
            end
        end

        //======================================================================
        // Test 12: Switch Value Change During Read
        //======================================================================
        $display("Test 12: Switch changes during consecutive reads");
        slave_sw = 8'h11;
        repeat(5) @(posedge clk);
        master_read(7'h57);
        if (master_rx_data != 8'h11) begin fail_count++; $display("  ✗ FAIL (read 1)\n"); end
        else begin
            slave_sw = 8'h22;
            repeat(5) @(posedge clk);
            master_read(7'h57);
            if (master_rx_data != 8'h22) begin fail_count++; $display("  ✗ FAIL (read 2)\n"); end
            else begin
                slave_sw = 8'h44;
                repeat(5) @(posedge clk);
                master_read(7'h57);
                if (master_rx_data == 8'h44 && !master_ack_error)
                    begin pass_count++; $display("  ✓ PASS (tracked SW changes correctly)\n"); end
                else
                    begin fail_count++; $display("  ✗ FAIL (read 3, rx_data=0x%0h)\n", master_rx_data); end
            end
        end

        //======================================================================
        // Final Results
        //======================================================================
        repeat(50) @(posedge clk);

        $display("================================================================================");
        $display("FINAL RESULTS:");
        $display("  PASSED: %0d/12", pass_count);
        $display("  FAILED: %0d/12", fail_count);
        $display("================================================================================");

        if (fail_count == 0) begin
            $display("✓ ALL TESTS PASSED!");
            $display("");
            $display("Board-to-board communication verified successfully!");
            $display("Ready for deployment on two separate Basys3 boards.");
        end else begin
            $display("✗ SOME TESTS FAILED");
        end

        $display("================================================================================");
        $display("");

        $finish;
    end

    //==========================================================================
    // Timeout watchdog
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout
        $display("\n✗ TIMEOUT - Simulation exceeded 50ms");
        $finish;
    end

endmodule

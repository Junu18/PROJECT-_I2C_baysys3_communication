`timescale 1ns / 1ps

//==============================================================================
// Slave Register Map
//==============================================================================
// Memory-mapped registers for LED and FND control
// Register Map:
//   0x00: SW_DATA   (Read-only)  - Switch input [7:0]
//   0x01: LED_LOW   (Read/Write) - LED[7:0]
//   0x02: LED_HIGH  (Read/Write) - LED[15:8]
//   0x03: FND_DATA  (Read/Write) - FND display data
//==============================================================================

module slave_register_map (
    input  logic       clk,
    input  logic       rst_n,

    // Register interface from protocol
    input  logic [7:0] reg_addr,
    input  logic [7:0] reg_wdata,
    input  logic       reg_wen,
    input  logic       reg_ren,
    output logic [7:0] reg_rdata,

    // External I/O
    input  logic [15:0] SW,           // Switch input
    output logic [15:0] LED,          // LED output
    output logic [6:0]  SEG,          // 7-segment display
    output logic [3:0]  AN            // 7-segment anode
);

    //==========================================================================
    // Register Addresses
    //==========================================================================
    localparam logic [7:0] ADDR_SW_DATA  = 8'h00;
    localparam logic [7:0] ADDR_LED_LOW  = 8'h01;
    localparam logic [7:0] ADDR_LED_HIGH = 8'h02;
    localparam logic [7:0] ADDR_FND_DATA = 8'h03;

    //==========================================================================
    // Internal Registers
    //==========================================================================
    logic [15:0] led_reg;
    logic [7:0]  fnd_data_reg;

    //==========================================================================
    // LED Output
    //==========================================================================
    assign LED = led_reg;

    //==========================================================================
    // Register Write
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_reg      <= 16'h0000;
            fnd_data_reg <= 8'h00;
        end else if (reg_wen) begin
            case (reg_addr)
                ADDR_LED_LOW:  led_reg[7:0]  <= reg_wdata;
                ADDR_LED_HIGH: led_reg[15:8] <= reg_wdata;
                ADDR_FND_DATA: fnd_data_reg  <= reg_wdata;
                default: begin
                    // No write to read-only registers
                end
            endcase
        end
    end

    //==========================================================================
    // Register Read
    //==========================================================================
    always_comb begin
        case (reg_addr)
            ADDR_SW_DATA:  reg_rdata = SW[7:0];        // Switch input
            ADDR_LED_LOW:  reg_rdata = led_reg[7:0];
            ADDR_LED_HIGH: reg_rdata = led_reg[15:8];
            ADDR_FND_DATA: reg_rdata = fnd_data_reg;
            default:       reg_rdata = 8'h00;
        endcase
    end

    //==========================================================================
    // 7-Segment Display Controller
    //==========================================================================
    // Simple 7-segment decoder for single digit
    // Displays lower 4 bits of fnd_data_reg

    logic [3:0] digit;
    assign digit = fnd_data_reg[3:0];

    // BCD to 7-segment decoder
    //     a
    //   f   b
    //     g
    //   e   c
    //     d
    // SEG = {dp, g, f, e, d, c, b, a} (active low for common anode)
    // For simplicity, using active high here - adjust based on your board

    always_comb begin
        case (digit)
            4'h0: SEG = 7'b0111111;  // 0
            4'h1: SEG = 7'b0000110;  // 1
            4'h2: SEG = 7'b1011011;  // 2
            4'h3: SEG = 7'b1001111;  // 3
            4'h4: SEG = 7'b1100110;  // 4
            4'h5: SEG = 7'b1101101;  // 5
            4'h6: SEG = 7'b1111101;  // 6
            4'h7: SEG = 7'b0000111;  // 7
            4'h8: SEG = 7'b1111111;  // 8
            4'h9: SEG = 7'b1101111;  // 9
            4'hA: SEG = 7'b1110111;  // A
            4'hB: SEG = 7'b1111100;  // b
            4'hC: SEG = 7'b0111001;  // C
            4'hD: SEG = 7'b1011110;  // d
            4'hE: SEG = 7'b1111001;  // E
            4'hF: SEG = 7'b1110001;  // F
            default: SEG = 7'b0000000;
        endcase
    end

    // Enable only first digit (simple version)
    assign AN = 4'b1110;  // Enable rightmost digit (active low)

endmodule

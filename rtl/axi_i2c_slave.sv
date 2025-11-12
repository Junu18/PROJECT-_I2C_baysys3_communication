`timescale 1ns / 1ps

//==============================================================================
// AXI-Lite I2C Slave
//==============================================================================
// AXI-Lite slave interface wrapper for I2C Slave core
// Compatible with MicroBlaze and other AXI masters
//==============================================================================

module axi_i2c_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6
)(
    //==========================================================================
    // AXI-Lite Interface
    //==========================================================================
    // Global
    input  wire                                 S_AXI_ACLK,
    input  wire                                 S_AXI_ARESETN,

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                           S_AXI_AWPROT,
    input  wire                                 S_AXI_AWVALID,
    output wire                                 S_AXI_AWREADY,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                 S_AXI_WVALID,
    output wire                                 S_AXI_WREADY,

    // Write Response Channel
    output wire [1:0]                           S_AXI_BRESP,
    output wire                                 S_AXI_BVALID,
    input  wire                                 S_AXI_BREADY,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                           S_AXI_ARPROT,
    input  wire                                 S_AXI_ARVALID,
    output wire                                 S_AXI_ARREADY,

    // Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                           S_AXI_RRESP,
    output wire                                 S_AXI_RVALID,
    input  wire                                 S_AXI_RREADY,

    //==========================================================================
    // I2C Interface
    //==========================================================================
    input  wire                                 scl,
    inout  wire                                 sda,

    //==========================================================================
    // Interrupt
    //==========================================================================
    output wire                                 interrupt
);

    //==========================================================================
    // Register Map
    //==========================================================================
    // 0x00: CTRL   - Control Register (W)
    // 0x04: STAT   - Status Register (R)
    // 0x08: ADDR   - Own Slave Address (W)
    // 0x0C: TXDATA - Transmit Data (W) - data to send to master on read
    // 0x10: RXDATA - Receive Data (R) - data received from master on write

    localparam ADDR_CTRL   = 6'h00;
    localparam ADDR_STAT   = 6'h04;
    localparam ADDR_ADDR   = 6'h08;
    localparam ADDR_TXDATA = 6'h0C;
    localparam ADDR_RXDATA = 6'h10;

    //==========================================================================
    // Internal Registers
    //==========================================================================
    logic [31:0] ctrl_reg;
    logic [31:0] stat_reg;
    logic [31:0] addr_reg;
    logic [31:0] txdata_reg;
    logic [31:0] rxdata_reg;

    // AXI signals
    logic        axi_awready;
    logic        axi_wready;
    logic [1:0]  axi_bresp;
    logic        axi_bvalid;
    logic        axi_arready;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic        axi_rvalid;

    // I2C Core signals
    logic [6:0]  i2c_slave_addr;
    logic [7:0]  i2c_tx_data;
    logic [7:0]  i2c_rx_data;
    logic        i2c_data_valid;
    logic        i2c_addr_match;
    logic        i2c_ack_sent;

    // Control signals
    logic        data_valid_prev;

    //==========================================================================
    // AXI Interface Assignments
    //==========================================================================
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    //==========================================================================
    // Interrupt Generation (data valid pulse)
    //==========================================================================
    assign interrupt = i2c_data_valid & ~data_valid_prev;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            data_valid_prev <= 1'b0;
        else
            data_valid_prev <= i2c_data_valid;
    end

    //==========================================================================
    // AXI Write Logic
    //==========================================================================
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b00;
            ctrl_reg    <= 32'd0;
            addr_reg    <= {25'd0, 7'b1010101}; // Default: 0x55
            txdata_reg  <= 32'd0;
        end else begin
            // Default ready states
            if (S_AXI_AWVALID && ~axi_awready)
                axi_awready <= 1'b1;
            else
                axi_awready <= 1'b0;

            if (S_AXI_WVALID && ~axi_wready)
                axi_wready <= 1'b1;
            else
                axi_wready <= 1'b0;

            // Write response
            if (axi_awready && axi_wready && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end

            // Register writes
            if (axi_awready && axi_wready) begin
                case (S_AXI_AWADDR[5:2])
                    ADDR_CTRL[5:2]:   ctrl_reg   <= S_AXI_WDATA;
                    ADDR_ADDR[5:2]:   addr_reg   <= S_AXI_WDATA;
                    ADDR_TXDATA[5:2]: txdata_reg <= S_AXI_WDATA;
                    default: ;
                endcase
            end
        end
    end

    //==========================================================================
    // AXI Read Logic
    //==========================================================================
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 32'd0;
            axi_rresp   <= 2'b00;
        end else begin
            // Address ready
            if (S_AXI_ARVALID && ~axi_rvalid)
                axi_arready <= 1'b1;
            else
                axi_arready <= 1'b0;

            // Read data valid
            if (axi_arready && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; // OKAY

                // Register reads
                case (S_AXI_ARADDR[5:2])
                    ADDR_CTRL[5:2]:   axi_rdata <= ctrl_reg;
                    ADDR_STAT[5:2]:   axi_rdata <= stat_reg;
                    ADDR_ADDR[5:2]:   axi_rdata <= addr_reg;
                    ADDR_TXDATA[5:2]: axi_rdata <= txdata_reg;
                    ADDR_RXDATA[5:2]: axi_rdata <= rxdata_reg;
                    default:          axi_rdata <= 32'd0;
                endcase
            end else if (S_AXI_RREADY && axi_rvalid) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Status Register Update
    //==========================================================================
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            stat_reg <= 32'd0;
        end else begin
            stat_reg[0] <= i2c_addr_match;  // Address matched
            stat_reg[1] <= i2c_ack_sent;    // ACK sent
            stat_reg[2] <= i2c_data_valid;  // Data valid (new data received)
        end
    end

    //==========================================================================
    // RX Data Register Update
    //==========================================================================
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rxdata_reg <= 32'd0;
        end else if (i2c_data_valid) begin
            rxdata_reg <= {24'd0, i2c_rx_data};
        end
    end

    //==========================================================================
    // I2C Core Signal Mapping
    //==========================================================================
    assign i2c_slave_addr = addr_reg[6:0];
    assign i2c_tx_data    = txdata_reg[7:0];

    //==========================================================================
    // I2C Slave Core Instance
    //==========================================================================
    i2c_slave i2c_core (
        .clk                (S_AXI_ACLK),
        .rst_n              (S_AXI_ARESETN),
        .slave_addr         (i2c_slave_addr),
        .tx_data            (i2c_tx_data),
        .rx_data            (i2c_rx_data),
        .data_valid         (i2c_data_valid),
        .scl                (scl),
        .sda                (sda),
        .debug_addr_match   (i2c_addr_match),
        .debug_ack_sent     (i2c_ack_sent),
        .debug_state        (),
        .debug_sda_out      (),
        .debug_sda_oe       ()
    );

endmodule

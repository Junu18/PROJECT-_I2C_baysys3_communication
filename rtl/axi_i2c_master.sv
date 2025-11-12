`timescale 1ns / 1ps

//==============================================================================
// AXI-Lite I2C Master
//==============================================================================
// AXI-Lite slave interface wrapper for I2C Master core
// Compatible with MicroBlaze and other AXI masters
//==============================================================================

module axi_i2c_master #(
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
    inout  wire                                 scl,
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
    // 0x08: ADDR   - Slave Address (W)
    // 0x0C: TXDATA - Transmit Data (W)
    // 0x10: RXDATA - Receive Data (R)
    // 0x14: CONFIG - Configuration (W)

    localparam ADDR_CTRL   = 6'h00;
    localparam ADDR_STAT   = 6'h04;
    localparam ADDR_ADDR   = 6'h08;
    localparam ADDR_TXDATA = 6'h0C;
    localparam ADDR_RXDATA = 6'h10;
    localparam ADDR_CONFIG = 6'h14;

    //==========================================================================
    // Internal Registers
    //==========================================================================
    logic [31:0] ctrl_reg;
    logic [31:0] stat_reg;
    logic [31:0] addr_reg;
    logic [31:0] txdata_reg;
    logic [31:0] rxdata_reg;
    logic [31:0] config_reg;

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
    logic        i2c_start;
    logic        i2c_rw_bit;
    logic [6:0]  i2c_slave_addr;
    logic [7:0]  i2c_tx_data;
    logic [7:0]  i2c_rx_data;
    logic        i2c_busy;
    logic        i2c_done;
    logic        i2c_ack_error;

    // Control signals
    logic        start_pulse;
    logic        done_prev;

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
    // Interrupt Generation (done pulse)
    //==========================================================================
    assign interrupt = i2c_done & ~done_prev;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            done_prev <= 1'b0;
        else
            done_prev <= i2c_done;
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
            addr_reg    <= 32'd0;
            txdata_reg  <= 32'd0;
            config_reg  <= 32'd0;
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
                    ADDR_CONFIG[5:2]: config_reg <= S_AXI_WDATA;
                    default: ;
                endcase
            end

            // Auto-clear START bit after pulse
            if (start_pulse)
                ctrl_reg[0] <= 1'b0;
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
                    ADDR_CONFIG[5:2]: axi_rdata <= config_reg;
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
            stat_reg[0] <= i2c_busy;      // BUSY
            stat_reg[1] <= i2c_ack_error; // NACK
            stat_reg[2] <= i2c_done;      // DONE
        end
    end

    //==========================================================================
    // RX Data Register Update
    //==========================================================================
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rxdata_reg <= 32'd0;
        end else if (i2c_done && !i2c_ack_error) begin
            rxdata_reg <= {24'd0, i2c_rx_data};
        end
    end

    //==========================================================================
    // Start Pulse Generation
    //==========================================================================
    logic ctrl_reg_prev;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            ctrl_reg_prev <= 1'b0;
        else
            ctrl_reg_prev <= ctrl_reg[0];
    end

    assign start_pulse = ctrl_reg[0] & ~ctrl_reg_prev;

    //==========================================================================
    // I2C Core Signal Mapping
    //==========================================================================
    assign i2c_start      = start_pulse;
    assign i2c_slave_addr = addr_reg[6:0];
    assign i2c_tx_data    = txdata_reg[7:0];
    assign i2c_rw_bit     = config_reg[0];  // bit[0] of CONFIG = R/W

    //==========================================================================
    // I2C Master Core Instance
    //==========================================================================
    i2c_master i2c_core (
        .clk            (S_AXI_ACLK),
        .rst_n          (S_AXI_ARESETN),
        .start          (i2c_start),
        .rw_bit         (i2c_rw_bit),
        .slave_addr     (i2c_slave_addr),
        .tx_data        (i2c_tx_data),
        .rx_data        (i2c_rx_data),
        .busy           (i2c_busy),
        .done           (i2c_done),
        .ack_error      (i2c_ack_error),
        .sda            (sda),
        .scl            (scl),
        .debug_busy     (),
        .debug_ack      (),
        .debug_state    (),
        .debug_scl      (),
        .debug_sda_out  (),
        .debug_sda_oe   ()
    );

endmodule

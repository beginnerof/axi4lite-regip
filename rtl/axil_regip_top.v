// AXI4-Lite Register IP top: protocol IF + parameterized register bank

module axil_regip_top #(
    parameter integer ADDR_WIDTH = 8,
    parameter integer NUM_REGS   = 8,
    parameter [31:0]  VERSION    = 32'h0001_0000
) (
    input  wire        ACLK,
    input  wire        ARESETn,

    input  wire [31:0] AWADDR,
    input  wire [2:0]  AWPROT,
    input  wire        AWVALID,
    output wire        AWREADY,

    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output wire        WREADY,

    output wire [1:0]  BRESP,
    output wire        BVALID,
    input  wire        BREADY,

    input  wire [31:0] ARADDR,
    input  wire [2:0]  ARPROT,
    input  wire        ARVALID,
    output wire        ARREADY,

    output wire [31:0] RDATA,
    output wire [1:0]  RRESP,
    output wire        RVALID,
    input  wire        RREADY,

    output wire        irq
);

    wire                   reg_we, reg_wresp_ok, reg_rresp_ok;
    wire [ADDR_WIDTH-1:0]  reg_waddr, reg_raddr;
    wire [31:0]            reg_wdata, reg_rdata;
    wire [3:0]             reg_wstrb;

    axi4lite_if #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_if (
        .ACLK          (ACLK),
        .ARESETn       (ARESETn),
        .AWADDR        (AWADDR),
        .AWPROT        (AWPROT),
        .AWVALID       (AWVALID),
        .AWREADY       (AWREADY),
        .WDATA         (WDATA),
        .WSTRB         (WSTRB),
        .WVALID        (WVALID),
        .WREADY        (WREADY),
        .BRESP         (BRESP),
        .BVALID        (BVALID),
        .BREADY        (BREADY),
        .ARADDR        (ARADDR),
        .ARPROT        (ARPROT),
        .ARVALID       (ARVALID),
        .ARREADY       (ARREADY),
        .RDATA         (RDATA),
        .RRESP         (RRESP),
        .RVALID        (RVALID),
        .RREADY        (RREADY),
        .reg_we        (reg_we),
        .reg_waddr     (reg_waddr),
        .reg_wdata     (reg_wdata),
        .reg_wstrb     (reg_wstrb),
        .reg_wresp_ok  (reg_wresp_ok),
        .reg_raddr     (reg_raddr),
        .reg_rdata     (reg_rdata),
        .reg_rresp_ok  (reg_rresp_ok)
    );

    reg_bank #(
        .NUM_REGS   (NUM_REGS),
        .ADDR_WIDTH (ADDR_WIDTH),
        .VERSION    (VERSION)
    ) u_bank (
        .clk       (ACLK),
        .rst_n     (ARESETn),
        .we        (reg_we),
        .waddr     (reg_waddr),
        .wdata     (reg_wdata),
        .wstrb     (reg_wstrb),
        .wresp_ok  (reg_wresp_ok),
        .raddr     (reg_raddr),
        .rdata     (reg_rdata),
        .rresp_ok  (reg_rresp_ok),
        .irq       (irq)
    );

endmodule

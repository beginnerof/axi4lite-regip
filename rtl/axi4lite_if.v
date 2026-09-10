// AXI4-Lite slave protocol engine.
// AW and W may arrive in either order. One outstanding write and one
// outstanding read may proceed concurrently (separate address ports).

module axi4lite_if #(
    parameter integer ADDR_WIDTH = 8,
    parameter integer NUM_REGS   = 8
) (
    input  wire                    ACLK,
    input  wire                    ARESETn,

    input  wire [31:0]             AWADDR,
    input  wire [2:0]              AWPROT,
    input  wire                    AWVALID,
    output wire                    AWREADY,

    input  wire [31:0]             WDATA,
    input  wire [3:0]              WSTRB,
    input  wire                    WVALID,
    output wire                    WREADY,

    output wire [1:0]              BRESP,
    output wire                    BVALID,
    input  wire                    BREADY,

    input  wire [31:0]             ARADDR,
    input  wire [2:0]              ARPROT,
    input  wire                    ARVALID,
    output wire                    ARREADY,

    output wire [31:0]             RDATA,
    output wire [1:0]              RRESP,
    output wire                    RVALID,
    input  wire                    RREADY,

    // Write port to bank
    output reg                     reg_we,
    output reg  [ADDR_WIDTH-1:0]   reg_waddr,
    output reg  [31:0]             reg_wdata,
    output reg  [3:0]              reg_wstrb,
    input  wire                    reg_wresp_ok,

    // Read port to bank
    output reg  [ADDR_WIDTH-1:0]   reg_raddr,
    input  wire [31:0]             reg_rdata,
    input  wire                    reg_rresp_ok
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // ---------------- Write path ----------------
    reg        aw_done, w_done;
    reg [31:0] aw_addr_q, w_data_q;
    reg [3:0]  w_strb_q;
    reg        bvalid_q;
    reg [1:0]  bresp_q;

    assign AWREADY = ARESETn && !aw_done && !bvalid_q;
    assign WREADY  = ARESETn && !w_done  && !bvalid_q;
    assign BVALID  = bvalid_q;
    assign BRESP   = bresp_q;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_done    <= 1'b0;
            w_done     <= 1'b0;
            aw_addr_q  <= 32'd0;
            w_data_q   <= 32'd0;
            w_strb_q   <= 4'd0;
            bvalid_q   <= 1'b0;
            bresp_q    <= RESP_OKAY;
            reg_we     <= 1'b0;
            reg_waddr  <= {ADDR_WIDTH{1'b0}};
            reg_wdata  <= 32'd0;
            reg_wstrb  <= 4'd0;
        end else begin
            reg_we <= 1'b0;

            if (AWVALID && AWREADY) begin
                aw_addr_q <= AWADDR;
                aw_done   <= 1'b1;
            end
            if (WVALID && WREADY) begin
                w_data_q <= WDATA;
                w_strb_q <= WSTRB;
                w_done   <= 1'b1;
            end

            // Both channels captured (or arriving this cycle via flags from prior)
            if (aw_done && w_done && !bvalid_q) begin
                reg_we    <= 1'b1;
                reg_waddr <= aw_addr_q[ADDR_WIDTH-1:0];
                reg_wdata <= w_data_q;
                reg_wstrb <= w_strb_q;
                // Alignment + range: same rule as bank wresp_ok
                bresp_q   <= (aw_addr_q[1:0] == 2'b00 &&
                              aw_addr_q[31:2] < NUM_REGS) ? RESP_OKAY : RESP_SLVERR;
                bvalid_q  <= 1'b1;
                aw_done   <= 1'b0;
                w_done    <= 1'b0;
            end

            if (bvalid_q && BREADY)
                bvalid_q <= 1'b0;
        end
    end

    // ---------------- Read path ----------------
    reg                  rvalid_q;
    reg [31:0]           rdata_q;
    reg [1:0]            rresp_q;
    reg                  capture_rd;
    reg [ADDR_WIDTH-1:0] raddr_q;

    assign ARREADY = ARESETn && !rvalid_q;
    assign RVALID  = rvalid_q;
    assign RDATA   = rdata_q;
    assign RRESP   = rresp_q;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rvalid_q    <= 1'b0;
            rdata_q     <= 32'd0;
            rresp_q     <= RESP_OKAY;
            capture_rd  <= 1'b0;
            reg_raddr   <= {ADDR_WIDTH{1'b0}};
            raddr_q     <= {ADDR_WIDTH{1'b0}};
        end else begin
            capture_rd <= 1'b0;

            if (ARVALID && ARREADY) begin
                reg_raddr  <= ARADDR[ADDR_WIDTH-1:0];
                raddr_q    <= ARADDR[ADDR_WIDTH-1:0];
                capture_rd <= 1'b1;
            end

            // Combinational bank read; sample the cycle after AR handshake
            if (capture_rd) begin
                rdata_q  <= reg_rdata;
                rresp_q  <= reg_rresp_ok ? RESP_OKAY : RESP_SLVERR;
                rvalid_q <= 1'b1;
            end

            if (rvalid_q && RREADY)
                rvalid_q <= 1'b0;
        end
    end

endmodule

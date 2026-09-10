// Parameterized register bank: RW / RO / W1S / W1C
// Separate write and read address ports so AXI R/W can overlap.

module reg_bank #(
    parameter integer NUM_REGS   = 8,
    parameter integer ADDR_WIDTH = 8,
    parameter [31:0]  VERSION    = 32'h0001_0000
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Write port
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    waddr,
    input  wire [31:0]              wdata,
    input  wire [3:0]               wstrb,
    output wire                     wresp_ok,

    // Read port (combinational)
    input  wire [ADDR_WIDTH-1:0]    raddr,
    output reg  [31:0]              rdata,
    output wire                     rresp_ok,
    output wire                     irq
);

    localparam [1:0] ATTR_RW  = 2'd0;
    localparam [1:0] ATTR_RO  = 2'd1;
    localparam [1:0] ATTR_W1S = 2'd2;
    localparam [1:0] ATTR_W1C = 2'd3;

    reg [31:0] regs [0:NUM_REGS-1];

    function addr_ok;
        input [ADDR_WIDTH-1:0] a;
        reg [ADDR_WIDTH-3:0] idx;
        begin
            idx = a[ADDR_WIDTH-1:2];
            addr_ok = (a[1:0] == 2'b00) &&
                      ({{(32-ADDR_WIDTH+2){1'b0}}, idx} < NUM_REGS);
        end
    endfunction

    function [1:0] reg_attr;
        input integer idx;
        begin
            case (idx)
                1:       reg_attr = ATTR_RO;   // STATUS
                3:       reg_attr = ATTR_W1C;  // IRQ_STAT
                4:       reg_attr = ATTR_W1S;  // IRQ_SET
                7:       reg_attr = ATTR_RO;   // VERSION
                default: reg_attr = ATTR_RW;
            endcase
        end
    endfunction

    function [31:0] apply_strb;
        input [31:0] old;
        input [31:0] nw;
        input [3:0]  strb;
        integer i;
        begin
            apply_strb = old;
            for (i = 0; i < 4; i = i + 1)
                if (strb[i])
                    apply_strb[i*8 +: 8] = nw[i*8 +: 8];
        end
    endfunction

    function [31:0] apply_w1c;
        input [31:0] old;
        input [31:0] nw;
        input [3:0]  strb;
        integer i;
        begin
            apply_w1c = old;
            for (i = 0; i < 32; i = i + 1)
                if (strb[i/8] && nw[i])
                    apply_w1c[i] = 1'b0;
        end
    endfunction

    function [31:0] apply_w1s;
        input [31:0] old;
        input [31:0] nw;
        input [3:0]  strb;
        integer i;
        begin
            apply_w1s = old;
            for (i = 0; i < 32; i = i + 1)
                if (strb[i/8] && nw[i])
                    apply_w1s[i] = 1'b1;
        end
    endfunction

    assign wresp_ok = addr_ok(waddr);
    assign rresp_ok = addr_ok(raddr);
    assign irq      = |(regs[3] & regs[2]);

    integer i;
    reg [1:0]  attr;
    reg [31:0] cur;
    reg [ADDR_WIDTH-3:0] widx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= 32'd0;
            regs[7] <= VERSION;
        end else if (we && addr_ok(waddr)) begin
            widx = waddr[ADDR_WIDTH-1:2];
            attr = reg_attr(widx);
            // IRQ_SET (idx 4) is W1S into IRQ_STAT (idx 3); SET cell itself stays 0
            if (widx == 4)
                regs[3] <= apply_w1s(regs[3], wdata, wstrb);
            else begin
                cur = regs[widx];
                case (attr)
                    ATTR_RW:  regs[widx] <= apply_strb(cur, wdata, wstrb);
                    ATTR_W1S: regs[widx] <= apply_w1s (cur, wdata, wstrb);
                    ATTR_W1C: regs[widx] <= apply_w1c (cur, wdata, wstrb);
                    default:  ;
                endcase
            end
        end
    end

    always @* begin
        if (!addr_ok(raddr)) begin
            rdata = 32'd0;
        end else begin
            case (raddr[ADDR_WIDTH-1:2])
                1: rdata = {30'd0, irq, regs[0][0]}; // STATUS
                4: rdata = 32'd0;                    // IRQ_SET reads 0
                default: rdata = regs[raddr[ADDR_WIDTH-1:2]];
            endcase
        end
    end

endmodule

// Self-checking testbench for axil_regip_top
`timescale 1ns/1ps

module tb_axil_regip;

    localparam ADDR_WIDTH = 8;
    localparam NUM_REGS   = 8;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // Register offsets
    localparam OFF_CTRL     = 8'h00;
    localparam OFF_STATUS   = 8'h04;
    localparam OFF_IRQ_EN   = 8'h08;
    localparam OFF_IRQ_STAT = 8'h0C;
    localparam OFF_IRQ_SET  = 8'h10;
    localparam OFF_DATA0    = 8'h14;
    localparam OFF_DATA1    = 8'h18;
    localparam OFF_VERSION  = 8'h1C;

    reg         ACLK = 1'b0;
    reg         ARESETn = 1'b0;

    reg  [31:0] AWADDR = 32'd0;
    reg  [2:0]  AWPROT = 3'd0;
    reg         AWVALID = 1'b0;
    wire        AWREADY;

    reg  [31:0] WDATA = 32'd0;
    reg  [3:0]  WSTRB = 4'hF;
    reg         WVALID = 1'b0;
    wire        WREADY;

    wire [1:0]  BRESP;
    wire        BVALID;
    reg         BREADY = 1'b1;

    reg  [31:0] ARADDR = 32'd0;
    reg  [2:0]  ARPROT = 3'd0;
    reg         ARVALID = 1'b0;
    wire        ARREADY;

    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    reg         RREADY = 1'b1;

    wire        irq;

    integer errors = 0;
    integer checks = 0;

    axil_regip_top #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS),
        .VERSION    (32'h0001_0000)
    ) dut (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        .AWADDR  (AWADDR),
        .AWPROT  (AWPROT),
        .AWVALID (AWVALID),
        .AWREADY (AWREADY),
        .WDATA   (WDATA),
        .WSTRB   (WSTRB),
        .WVALID  (WVALID),
        .WREADY  (WREADY),
        .BRESP   (BRESP),
        .BVALID  (BVALID),
        .BREADY  (BREADY),
        .ARADDR  (ARADDR),
        .ARPROT  (ARPROT),
        .ARVALID (ARVALID),
        .ARREADY (ARREADY),
        .RDATA   (RDATA),
        .RRESP   (RRESP),
        .RVALID  (RVALID),
        .RREADY  (RREADY),
        .irq     (irq)
    );

    always #5 ACLK = ~ACLK;

    task check;
        input cond;
        input [511:0] name;
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("[FAIL] %0s (t=%0t)", name, $time);
            end else begin
                $display("[ OK ] %0s", name);
            end
        end
    endtask

    // Simple write: drive AW and W together, wait for B
    reg [1:0] last_bresp;

    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        input        aw_first; // 1: AW then W; 0: W then AW
        begin
            @(posedge ACLK);
            if (aw_first) begin
                AWADDR  <= addr;
                AWVALID <= 1'b1;
                @(posedge ACLK);
                while (!AWREADY) @(posedge ACLK);
                AWVALID <= 1'b0;

                WDATA  <= data;
                WSTRB  <= strb;
                WVALID <= 1'b1;
                @(posedge ACLK);
                while (!WREADY) @(posedge ACLK);
                WVALID <= 1'b0;
            end else begin
                WDATA  <= data;
                WSTRB  <= strb;
                WVALID <= 1'b1;
                @(posedge ACLK);
                while (!WREADY) @(posedge ACLK);
                WVALID <= 1'b0;

                AWADDR  <= addr;
                AWVALID <= 1'b1;
                @(posedge ACLK);
                while (!AWREADY) @(posedge ACLK);
                AWVALID <= 1'b0;
            end

            BREADY <= 1'b1;
            @(posedge ACLK);
            while (!BVALID) @(posedge ACLK);
            last_bresp = BRESP;
            @(posedge ACLK);
        end
    endtask

    task axi_write_resp;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        output [1:0] resp;
        begin
            axi_write(addr, data, strb, 1'b1);
            resp = last_bresp;
        end
    endtask

    task axi_read;
        input  [31:0] addr;
        output [31:0] data;
        output [1:0]  resp;
        begin
            @(posedge ACLK);
            ARADDR  <= addr;
            ARVALID <= 1'b1;
            @(posedge ACLK);
            while (!ARREADY) @(posedge ACLK);
            ARVALID <= 1'b0;

            RREADY <= 1'b1;
            @(posedge ACLK);
            while (!RVALID) @(posedge ACLK);
            data = RDATA;
            resp = RRESP;
            @(posedge ACLK);
        end
    endtask

    reg [31:0] rd;
    reg [1:0]  rp;
    reg [1:0]  wp;
    integer    i;
    reg [31:0] rnd_addr, rnd_data;
    reg [3:0]  rnd_strb;

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("tb_axil_regip.vcd");
            $dumpvars(0, tb_axil_regip);
        end

        ARESETn = 1'b0;
        repeat (5) @(posedge ACLK);
        ARESETn = 1'b1;
        repeat (2) @(posedge ACLK);

        // --- 1. Reset defaults ---
        axi_read(OFF_VERSION, rd, rp);
        check(rp == RESP_OKAY && rd == 32'h0001_0000, "reset: VERSION == 0x00010000");

        axi_read(OFF_CTRL, rd, rp);
        check(rp == RESP_OKAY && rd == 32'd0, "reset: CTRL == 0");

        // --- 2. RW write/read DATA0/DATA1 ---
        axi_write(OFF_DATA0, 32'hDEADBEEF, 4'hF, 1'b1);
        axi_read (OFF_DATA0, rd, rp);
        check(rp == RESP_OKAY && rd == 32'hDEADBEEF, "DATA0 readback");

        axi_write(OFF_DATA1, 32'h12345678, 4'hF, 1'b0); // W-before-AW
        axi_read (OFF_DATA1, rd, rp);
        check(rp == RESP_OKAY && rd == 32'h12345678, "DATA1 readback (W first)");

        // --- 3. CTRL + STATUS mirror ---
        axi_write(OFF_CTRL, 32'h00000001, 4'hF, 1'b1);
        axi_read (OFF_STATUS, rd, rp);
        check(rp == RESP_OKAY && rd[0] == 1'b1, "STATUS.enable follows CTRL");

        // --- 4. WSTRB byte enable ---
        axi_write(OFF_DATA0, 32'hAABBCCDD, 4'b0011, 1'b1);
        axi_read (OFF_DATA0, rd, rp);
        check(rd == 32'hDEADCCDD, "WSTRB: only low 2 bytes updated");

        // --- 5. RO protection: write VERSION should not change it ---
        axi_write(OFF_VERSION, 32'hFFFFFFFF, 4'hF, 1'b1);
        axi_read (OFF_VERSION, rd, rp);
        check(rp == RESP_OKAY && rd == 32'h00010000, "VERSION is read-only");

        // --- 6. W1S / W1C / irq ---
        axi_write(OFF_IRQ_EN, 32'h00000003, 4'hF, 1'b1);
        axi_write(OFF_IRQ_SET, 32'h00000005, 4'hF, 1'b1);
        axi_read (OFF_IRQ_STAT, rd, rp);
        check(rd == 32'h00000005, "IRQ_SET sets bits");
        check(irq === 1'b1, "irq asserted when STAT & EN");

        axi_write(OFF_IRQ_STAT, 32'h00000004, 4'hF, 1'b1); // clear bit2
        axi_read (OFF_IRQ_STAT, rd, rp);
        check(rd == 32'h00000001, "IRQ_STAT W1C clears only written 1s");
        check(irq === 1'b1, "irq still set (bit0 remains, enabled)");

        axi_write(OFF_IRQ_STAT, 32'h00000001, 4'hF, 1'b1);
        check(irq === 1'b0, "irq cleared when all bits gone");

        // IRQ_SET reads as 0
        axi_read (OFF_IRQ_SET, rd, rp);
        check(rp == RESP_OKAY && rd == 32'd0, "IRQ_SET reads as 0");

        // --- 7. Illegal / unaligned address -> SLVERR ---
        axi_write(8'h20, 32'h1, 4'hF, 1'b1); // beyond 8 regs
        wp = last_bresp;
        check(wp == RESP_SLVERR, "write out-of-range -> SLVERR");

        axi_read (8'h20, rd, rp);
        check(rp == RESP_SLVERR, "read out-of-range -> SLVERR");

        axi_write(8'h02, 32'h1, 4'hF, 1'b1); // unaligned
        wp = last_bresp;
        check(wp == RESP_SLVERR, "unaligned write -> SLVERR");

        axi_read (8'h02, rd, rp);
        check(rp == RESP_SLVERR, "unaligned read -> SLVERR");

        // --- 8. Random smoke ---
        for (i = 0; i < 40; i = i + 1) begin
            rnd_addr = {$random} % NUM_REGS * 4;
            rnd_data = $random;
            rnd_strb = $random;
            axi_write(rnd_addr, rnd_data, rnd_strb, i[0]);
            axi_read (rnd_addr, rd, rp);
            check(rp == RESP_OKAY, "random access OKAY");
        end

        // Final known-value check on DATA0 after randoms
        axi_write(OFF_DATA0, 32'h55AA55AA, 4'hF, 1'b1);
        axi_read (OFF_DATA0, rd, rp);
        check(rd == 32'h55AA55AA, "final DATA0 write/read");

        $display("----------------------------------------");
        if (errors == 0)
            $display("PASS  (%0d checks)", checks);
        else
            $display("FAIL  (%0d errors / %0d checks)", errors, checks);
        $display("----------------------------------------");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("[FAIL] timeout");
        $display("FAIL");
        $finish;
    end

endmodule

# AXI4-Lite handshake waveforms

Open `sim/tb_axil_regip.vcd` in GTKWave after `make test` (or the PowerShell flow in the README).

## Signals to add

| Signal | Meaning |
|--------|---------|
| `s_axi_awvalid` / `s_axi_awready` | Write address channel |
| `s_axi_awaddr` | Write address |
| `s_axi_wvalid` / `s_axi_wready` | Write data channel |
| `s_axi_wdata` / `s_axi_wstrb` | Write payload + byte enables |
| `s_axi_bvalid` / `s_axi_bready` / `s_axi_bresp` | Write response |
| `s_axi_arvalid` / `s_axi_arready` | Read address |
| `s_axi_rvalid` / `s_axi_rready` / `s_axi_rdata` / `s_axi_rresp` | Read data |

(Exact port names live in `rtl/axil_regip_top.v`.)

## What to look for

1. **VALID/READY** — a transfer happens only when both are high on the same rising edge.
2. **AW vs W order** — the testbench drives AW-first and W-first cases. Capture `aw_done` / `w_done` inside `rtl/axi4lite_if.v` to see pairing.
3. **WSTRB** — a write with `wstrb=4'b0011` must leave the upper half of the register unchanged.
4. **SLVERR** — unaligned or out-of-range address: `bresp`/`rresp` = `2'b10`.
5. **W1C / W1S** — after writing IRQ_STAT / IRQ_SET, watch the register bits and `irq` pin.

## ASCII sketch (AW then W)

```text
clk      : /\/\/\/\/\/\/\/\/\/
awvalid  : ____/~~~~~~~~~~\____
awready  : ______/~~\__________
wvalid   : ________/~~~~~~~~\__
wready   : ________/~~\________
bvalid   : ____________/~~~~\___
bready   : ~~~~~~~~~~~~~~~~~~~~
```

The write commits only after **both** AW and W have been accepted; B is returned after the register bank update.

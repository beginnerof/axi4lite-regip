# AXI4-Lite RegIP 设计说明

## 定位

可综合的 AXI4-Lite 从设备 IP：五通道协议机 + 参数化寄存器堆。
与 `rv32i-minisoc` 互补：前者是 CPU 核与简易 MMIO，本仓库聚焦标准总线从机协议与寄存器语义。

## 架构

```text
                 AXI4-Lite
    AW  W  B  AR  R
     |  |  |  |  |
     v  v  |  v  v
 +-------------------+
 |  axil_regip_top   |
 |  +--------------+ |
 |  | axi4lite_if  | |  握手 / 配对 AW+W / 响应
 |  +------+-------+ |
 |         | wr/rd   |
 |  +------v-------+ |
 |  |   reg_bank   | |  RW / RO / W1S / W1C
 |  +--------------+ |
 +-------------------+
          irq
```

## 寄存器映射（NUM_REGS=8）

| 偏移 | 名称 | 属性 | 说明 |
|------|------|------|------|
| 0x00 | CTRL | RW | [0] enable |
| 0x04 | STATUS | RO | [0] enable 镜像 [1] irq |
| 0x08 | IRQ_EN | RW | 中断使能掩码 |
| 0x0C | IRQ_STAT | W1C | 写 1 清对应位 |
| 0x10 | IRQ_SET | W1S | 写 1 置 IRQ_STAT 对应位（读回恒 0） |
| 0x14 | DATA0 | RW | 通用 scratch |
| 0x18 | DATA1 | RW | 通用 scratch |
| 0x1C | VERSION | RO | 0x0001_0000 |

`irq = |(IRQ_STAT & IRQ_EN)`

## 协议要点

- 写：AW 与 W 可任意顺序到达，均捕获后执行一次寄存器写，再回 B。
- 读：AR 握手后回 R；`RRESP` 为 `OKAY` 或 `SLVERR`。
- 非法地址、非字对齐地址 → `SLVERR`。
- `WSTRB` 按字节使能合并；W1C/W1S 仅对 `WSTRB` 对应字节内的 1 位有效。
- RO 寄存器写忽略（响应仍为 OKAY，表示“事务成功但不改状态”）；地址非法才是 SLVERR。

## 验证计划

1. 复位后默认值
2. RW 读写与回读
3. WSTRB 字节写
4. RO 保护（写 VERSION 不变）
5. W1S / W1C / irq 组合
6. 非法偏移与非对齐 → SLVERR
7. AW/W 分离到达
8. 随机事务烟雾测试

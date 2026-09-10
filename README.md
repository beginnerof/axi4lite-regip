# AXI4-Lite RegIP

我在学 SoC 总线时写的 **AXI4-Lite 从机 + 寄存器堆** IP，全部用 **Verilog-2001**，用 Icarus Verilog 本地仿真，不依赖仿真器 license。

做这个项目是想把 AXI 的五通道握手、写通道 AW/W 配对、WSTRB 字节写、OKAY/SLVERR 响应，以及常见寄存器语义（RW / RO / W1S / W1C）真正串起来，而不是只背协议条文。

> 仿真结果：`tb_axil_regip` 输出 `PASS`。

和我的另一个仓库 [rv32i-minisoc](https://github.com/beginnerof/rv32i-minisoc) 是互补关系：那边是 CPU 核 + 简易 MMIO 外设，这边聚焦标准总线从设备协议。

---

## 1. 背景知识

### 1.1 AXI4-Lite 是什么

AXI（Advanced eXtensible Interface）是 ARM AMBA 里常用的片上总线。  
**AXI4-Lite** 是简化版：只支持字访问、无突发（burst），适合寄存器型外设。

一次完整事务最多涉及 5 个通道：

| 通道 | 方向（主机→从机） | 作用 |
|------|-------------------|------|
| AW | 主→从 | 写地址 |
| W  | 主→从 | 写数据 + 字节使能 WSTRB |
| B  | 从→主 | 写响应 |
| AR | 主→从 | 读地址 |
| R  | 从→主 | 读数据 + 读响应 |

每个通道都是 **VALID/READY** 握手：双方都为 1 的那一拍，数据才被采样。

### 1.2 写事务为什么要“配对”

AXI 允许 **AW 和 W 以任意先后顺序** 到达从机：

```text
情况 A:  AW 先到，W 后到
情况 B:  W 先到，AW 后到
情况 C:  同一拍同时到
```

从机需要分别捕获 AW、W，**两边都齐了** 才真正写寄存器，然后再在 B 通道回响应。  
我在 `rtl/axi4lite_if.v` 里用 `aw_done` / `w_done` 两个标志做配对。

### 1.3 WSTRB

`WSTRB[3:0]` 每一位对应 `WDATA` 的一个字节：

```text
WSTRB = 4'b0011  →  只更新低 16 bit，高 16 bit 保持
```

对 W1C/W1S 寄存器，同样只对使能字节内的“写 1”位生效。

### 1.4 响应码

| BRESP/RRESP | 含义 |
|-------------|------|
| `OKAY` (00) | 事务成功 |
| `SLVERR` (10) | 从机错误 |

本 IP 的约定：

- 地址非法（未字对齐 / 越界）→ `SLVERR`
- 写只读寄存器 → 仍回 `OKAY`（事务合法，只是状态不变）

### 1.5 寄存器属性

| 属性 | 写行为 | 典型用途 |
|------|--------|----------|
| RW | 正常读写 | 控制字、数据缓冲 |
| RO | 写忽略 | 版本号、状态镜像 |
| W1S | 写 1 置位 | 中断置起 |
| W1C | 写 1 清零 | 中断状态、标志位 |

---

## 2. 快速开始

### 2.1 依赖

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) ≥ 11
- 可选：GTKWave

Windows：把 `iverilog.exe` / `vvp.exe` 所在目录加入 `PATH`。

### 2.2 一键仿真

```bash
make test
```

### 2.3 Windows PowerShell

```powershell
cd axi4lite-regip
New-Item -ItemType Directory -Force sim | Out-Null

$rtl = @('rtl/reg_bank.v','rtl/axi4lite_if.v','rtl/axil_regip_top.v')
iverilog -g2001 -o sim/tb_axil_regip.vvp @rtl tb/tb_axil_regip.v

Push-Location sim
vvp tb_axil_regip.vvp
Pop-Location
```

### 2.4 预期输出

```text
...
[ OK ] final DATA0 write/read
----------------------------------------
PASS  (32 checks)
----------------------------------------
```

波形：

```bash
make wave
gtkwave sim/tb_axil_regip.vcd
```

---

## 3. 架构

```text
              AXI4-Lite 五通道
    AW   W   B   AR   R
     |   |   |   |   |
     v   v   |   v   v
 +-----------------------+
 |    axil_regip_top     |
 |  +-----------------+  |
 |  |  axi4lite_if    |  |  握手 / AW+W 配对 / B、R 响应
 |  +--------+--------+  |
 |           | we/re/addr|
 |  +--------v--------+  |
 |  |    reg_bank     |  |  RW / RO / W1S / W1C
 |  +-----------------+  |
 +-----------------------+
              |
             irq = |(IRQ_STAT & IRQ_EN)
```

| 文件 | 作用 |
|------|------|
| `rtl/axi4lite_if.v` | AXI4-Lite 协议状态机 |
| `rtl/reg_bank.v` | 参数化寄存器堆 |
| `rtl/axil_regip_top.v` | 顶层封装 |
| `tb/tb_axil_regip.v` | 自检 testbench |
| `docs/design.md` | 设计说明 |

---

## 4. 寄存器映射

默认 `NUM_REGS = 8`，字对齐，偏移单位为字节：

| 偏移 | 名称 | 属性 | 说明 |
|------|------|------|------|
| 0x00 | CTRL | RW | [0] enable |
| 0x04 | STATUS | RO | [0] enable 镜像 [1] irq |
| 0x08 | IRQ_EN | RW | 中断使能掩码 |
| 0x0C | IRQ_STAT | W1C | 写 1 清对应位 |
| 0x10 | IRQ_SET | W1S | 写 1 置 IRQ_STAT 对应位（读回恒 0） |
| 0x14 | DATA0 | RW | 通用 scratch |
| 0x18 | DATA1 | RW | 通用 scratch |
| 0x1C | VERSION | RO | 固定 `0x0001_0000` |

---

## 5. 验证覆盖

`tb_axil_regip.v` 覆盖：

1. 复位默认值（VERSION / CTRL）
2. RW 读写回读
3. AW 先到、W 先到两种配对顺序
4. WSTRB 字节使能合并
5. RO 写保护
6. W1S / W1C 与 `irq` 组合逻辑
7. 越界地址、非对齐地址 → SLVERR
8. 随机地址/数据/字节使能烟雾测试

---

## 6. 我从这个项目里学到什么

- VALID/READY 不能只看一拍，要区分“通道已捕获”和“事务已提交”
- 写地址和写数据是两条独立通道，从机必须自己做配对状态
- SLVERR 要落在协议层（地址合法性），不要和“寄存器只读”混为一谈
- W1C/W1S 是寄存器语义问题，不是总线问题；总线只负责把数据搬进来

---

## License

MIT

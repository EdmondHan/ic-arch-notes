# 跨时钟域同步 (CDC) 设计集

完整实现跨时钟域同步的三种典型方案,覆盖 IC 设计中 CDC 场景的全部主流需求。每个模块均独立完成 RTL 设计、综合 (SkyWater 130nm)、self-checking 验证。

------

## 三种 CDC 方案对比

| 维度         | 异步 FIFO               | 脉冲同步器         | 握手同步器               |
| ------------ | ----------------------- | ------------------ | ------------------------ |
| **应用场景** | 多 bit 数据流 (高吞吐)  | 单 bit 事件 (中频) | 事件 + 数据 (可靠传递)   |
| **核心机制** | 格雷码双指针 + 共享存储 | Toggle 电平翻转    | req/ack 双向协议         |
| **每次传输** | 1 个数据/拍             | 1 个事件/几拍      | 1 个数据/6-10 拍         |
| **延迟**     | 几拍 (流水)             | ~3 个目标域周期    | 6-10 个周期 (双向握手)   |
| **可靠性**   | 不丢,但有满/空边界      | 脉冲不能太密       | **绝对不丢、不重**       |
| **面积**     | 较大 (含存储)           | 极小               | 中等                     |
| **典型用例** | 视频/音频流、总线桥     | 中断通知、状态翻转 | 配置寄存器写入、命令传递 |

### 选型指南

```
需要传输的是什么?
├── 高吞吐数据流(每拍都可能有数据)
│   └── ► 异步 FIFO
├── 偶发的单 bit 事件(脉冲)
│   ├── 脉冲不密(间隔 > 目标域 3 周期)
│   │   └── ► 脉冲同步器
│   └── 脉冲可能很密 / 需要确认到达
│       └── ► 握手同步器
└── 带数据的事件 + 必须可靠到达
    └── ► 握手同步器
```

------

## 模块一:异步 FIFO

基于格雷码双指针 + 两级同步器的标准跨时钟域 FIFO。

### 设计规格

- 数据位宽:8 bit (参数化)
- 深度:16 (参数化,需 2^N)
- 读写完全独立的异步时钟域
- 异步读 (组合输出)

### 关键设计点

- **格雷码指针**:跨时钟域同步时单 bit 不确定,避免组合状态错误
- **指针多 1 位**:用最高位区分"满"与"空"
- **满空判断不对称**:空 = 完全相等;满 = 高 2 位取反 + 低位相同

### 综合结果 (sky130 130nm)

| 指标     | 数值                     |
| -------- | ------------------------ |
| 总面积   | **6501 μm²**             |
| 标准单元 | 404                      |
| 触发器   | 168 (128 存储 + 40 控制) |

**PPA 分析**:存储占面积 78%。深度翻倍 (16→32) 面积约 1.84×。大容量场景应改用 SRAM 宏。

### 验证

- 双时钟 self-checking testbench (wclk 7ns / rclk 13ns 互质)
- 单时钟极简测试 (隔离 CDC 干扰)
- 双时钟测试 0 错误通过

详见 `async_fifo/README.md`

------

## 模块二:脉冲同步器

基于 Toggle (电平翻转) 的单 bit 脉冲跨时钟域传递。

### 工作原理

```
源域:                目标域:
src_pulse           sync_ff1 ─► sync_ff2 ─► sync_ff3
   │                              │             │
   ▼                              └─── XOR ─────┘
toggle (每次脉冲翻转)                      │
   │                                       ▼
   └─────► 跨域同步 ◄──────────         dst_pulse
                                  (检测 sync_ff2 跳变)
```

### 关键设计点

- **脉冲→电平**:源域将单拍脉冲转为持续电平翻转,避免窄脉冲被两级同步器漏采
- **电平→脉冲**:目标域用第三级 FF + XOR 检测跳变,还原成单拍脉冲
- **限制**:源脉冲间隔必须 ≥ 目标时钟 3 周期,否则会丢

### 综合结果 (sky130 130nm)

- 触发器:4 个 (1 个 toggle + 3 个同步链)
- 组合逻辑:几个门 (XOR 边沿检测 + 控制)

### 验证

- 双时钟 (源快目标慢,故意暴露窄脉冲风险)
- 源域发 20 个脉冲,计数器对比目标域接收数
- **20 发 20 收,0 错误**

详见 `pulse_sync/README.md`

------

## 模块三:握手同步器

req/ack 双向握手,可靠传递事件 + 数据。

### 接口契约

源域用户:

```
等 src_ready = 1 → 拉一拍 src_valid + 给 src_data → 等下次 src_ready
```

目标域用户:

```
看到 dst_valid = 1 → 这一拍从 dst_data 采走数据
```

### 4-Phase 握手协议

```
源域 FSM                        目标域 FSM
─────────────                  ─────────────
S_IDLE                         D_IDLE
  │ src_valid                    │ req_sync = 1 (源 req 同步过来)
  ▼ 锁存数据,拉 req              ▼ 拉 ack
S_REQ ─── req ────────────►  D_GOT (1 拍,dst_valid 拉一拍)
  │ ack_sync = 1                 │
  ▼ 拉低 req                     ▼
S_WAIT  ◄────── ack ───────  D_ACK
  │ ack_sync = 0                 │ req_sync = 0
  ▼                              ▼
S_IDLE                         D_IDLE
```

### 关键设计点

- **req/ack 是电平**:不是脉冲,持续拉高直到对方响应,跨域同步绝不会漏
- **数据稳定保证**:`src_data_reg` 在 req 期间不变,目标域采样安全 (不需要数据线的同步器)
- **dst_valid 单拍**:只在 D_GOT 状态拉一拍,防止用户重复消费
- **src_ready 反压**:S_IDLE 时拉高,告诉用户"可以发新的了"

### 综合结果 (sky130 130nm)

- 触发器:24 个 (2+2 状态 + 8 数据 + 2+2 双向同步器 + ...)
- 总单元:48 个

### 验证

- 双时钟 (sclk 28ns / dclk 10ns 互质,大频率差)
- self-checking:源域发 100 个递增数据,目标域队列对比
- **100 发 100 收,0 错误**

详见 `handshake_sync/README.md`

------

## 工程方法论 (跨三个模块的共性经验)

### 设计阶段

- 所有 CDC 都基于"**两级触发器同步器**"基础组件,但应用方式不同
- 跨时钟域信号 (req/ack) 必须是**持续电平**,不能是窄脉冲
- 跨时钟域**多 bit 数据**需要保证稳定 (FIFO 用格雷码、握手用 req 期间数据冻结)

### 验证阶段

- **Self-checking 是必须的**:参考队列/计数器自动对比,不能依赖肉眼看波形
- **互质时钟频率**:最大化暴露 CDC 时序问题
- 跨时钟域信号在仿真中正确,**不代表 ASIC 上不会出问题**:还需 SDC 约束 `set_false_path` / `set_max_delay`(实际流片要做)

### Debug 经验

- **综合通过 ≠ 功能正确**:Yosys 放过的 reg/wire 类型错,iverilog 立刻报错——多工具交叉验证有效
- **testbench 也会有 bug**:验证环境的正确性需与 DUT 同等认真对待
- 调试要算**关键量** (指针差值、计数器差值),不被绝对值的"大数字"误导

------

## 目录结构

```
cdc/
├── README.md                  ← 本文档
├── async_fifo/                ← 模块一
│   ├── top_fifo.v + 子模块
│   ├── tb_fifo.v / tb_simple.v
│   ├── synth_area.ys
│   └── README.md
├── pulse_sync/                ← 模块二
│   ├── sync_pulse.v
│   ├── sync_2ff.v             ← 基础电平同步器
│   ├── tb_pulse.v
│   ├── synth_pulse.ys
│   └── README.md
└── handshake_sync/            ← 模块三
    ├── sync_handshake.v
    ├── tb_handshake.v
    ├── synth_handshake.ys
    └── README.md
```

------

## 工具链

| 用途   | 工具                             |
| ------ | -------------------------------- |
| 仿真   | Icarus Verilog (iverilog -g2012) |
| 波形   | GTKWave                          |
| 综合   | Yosys 0.33                       |
| 工艺库 | SkyWater 130nm (sky130_fd_sc_hd) |
| 环境   | Ubuntu 24.04 (WSL2)              |

------

## 参考

- Clifford E. Cummings, *Simulation and Synthesis Techniques for Asynchronous FIFO Design*, SNUG 2002
- Clifford E. Cummings, *Clock Domain Crossing (CDC) Design & Verification Techniques Using SystemVerilog*, SNUG 2008
- Cliff Cummings, *Nonblocking Assignments in Verilog Synthesis, Coding Styles That Kill!*, SNUG 2000
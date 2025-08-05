# AXI Lite Multi-Register Slave 仿真项目

本项目实现了一个**支持多寄存器的AXI Lite Slave模块**，包含完整的AXI-Lite协议握手机制和典型Testbench激励，可直接在EDA Playground或本地仿真环境下运行，并支持波形输出和测试自动化。

## 项目结构

- `axi_lite_slave_regs.sv` —— AXI Lite多寄存器Slave模块
- `testbench.sv`           —— Testbench，包含自动写/读任务、波形转储
- `README.md`              —— 项目说明

## 功能说明

- 支持任意参数化寄存器数量（例：REG_NUM=4）
- 完整实现AXI Lite五大通道（AW/W/B/AR/R），支持ready/valid握手
- 支持写数据分字节写（WSTRB）
- 写非法/未实现地址时返回SLVERR响应，读返回特殊值（如`DEAD_BEEF`）

## 仿真/运行方式

### **在EDA Playground运行**

1. 左侧选择`SystemVerilog/Verilog`语言
2. 将`axi_lite_slave_regs.sv`粘贴到Design区，将`testbench.sv`粘贴到Testbench区
3. 勾选`Open EPWave after run`
4. 确保Testbench中有如下内容用于生成波形文件：
   ```systemverilog
   initial begin
       $dumpfile("dump.vcd");
       $dumpvars(0, tb_axi_lite_slave_regs); // 替换为你的testbench模块名
       ...
   end
<img width="1830" height="793" alt="image" src="https://github.com/user-attachments/assets/f7f9d581-655e-47d7-9316-0cabdb5e841d" />


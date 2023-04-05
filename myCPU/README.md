# Tiny CPU

### LAB 16

cache.v: 支持 Uncache 访问的 cache 模块

cpu_axi_interface.v: 修改以支持 Cache 的 Burst 传输

### LAB 14

IF_stage.v: 
1. 添加 TLB 例外判断
2. 修改 nextpc 添加 TLB Refill 例外取指

EXE_stage.v:
1. 添加 TLB 例外判断
2. 例外相关信号 (ex、excode、badvaddr) 添加 TLB 例外支持

cp0.v: 添加 TLB 例外修改 CP0 寄存器逻辑

### LAB 13

IF_stage.v: 添加 tlb_flush 重新取指逻辑

ID_stage.v: 添加 TLB 指令执行信号生成逻辑

EXE_stage.v: 
1. 执行 TLBP 指令
2. 解决 MTC0 与 TLBP 写后读相关

WB_stage.v: 
1. 传 TLB 指令执行信号给 tlb 模块与 cp0 模块
2. 实现 tlb 模块与 cp0 模块互连

cp0.v: 添加 TLB 管理相关寄存器

tlb.v: TLB 模块

### LAB 11

IF_stage.v: 
1. 修改 SRAM 接口为类 SRAM 接口
2. 修改阻塞逻辑 fs_ready_go
3. 添加相应缓存保持易变信号 fs_bd、fs_inst、nextpc

ID_stage.v: 清理例外发生时 IF 级指令

EXE_stage.v: 
1. 修改 SRAM 接口为类 SRAM 接口
1. 修改阻塞逻辑 es_ready_go

MEM_stage.v: 
1. 修改 SRAM 接口为类 SRAM 接口
1. 修改阻塞逻辑 ms_ready_go

cpu_axi_interface.v: 类 SRAM-AIX 转接桥

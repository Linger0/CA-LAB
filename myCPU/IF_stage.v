`include "mycpu.h"

module if_stage(
    input                           clk            ,
    input                           reset          ,
    //allwoin
    input                           ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD        -1:0] br_bus         ,
    //to ds
    output                          fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD  -1:0] fs_to_ds_bus   ,
    //from ws: for exception
    input  [`WS_TO_FS_BUS_WD  -1:0] ws_to_fs_bus   ,
    //tlb
    output [`FS_TO_TLB_BUS_WD -1:0] fs_to_tlb_bus  ,
    input  [`TLB_TO_FS_BUS_WD -1:0] tlb_to_fs_bus  , 
    // inst sram-like
    output        inst_req    ,
    output [ 1:0] inst_size   ,
    output [31:0] inst_addr   ,
    input  [31:0] inst_rdata  ,
    input         inst_addr_ok,
    input         inst_data_ok
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

reg         buf_nextpc_valid;
reg  [31:0] buf_nextpc;

wire        inst_addr_mapped;
wire        inst_tlb_ref;
wire        inst_tlb_inv;

wire        br;
wire        br_taken;
wire [31:0] br_target;
assign {br,br_taken,br_target} = br_bus;

wire        s0_found;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_v;
assign {s0_found,
        s0_pfn  ,
        s0_c    ,
        s0_v
       } = tlb_to_fs_bus;

assign fs_to_tlb_bus  = nextpc[31:12];

reg         buf_br;

reg         fs_inst_tlb_ref;
reg         fs_inst_tlb_inv;

wire        fs_pc_ex;
wire        fs_bd;
wire        fs_ex;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst_tlb_inv, //68:68
                       fs_inst_tlb_ref, //67:67
                       fs_pc_ex       , //66:66
                       fs_bd          , //65:65
                       fs_ex          , //64:64
                       fs_inst        , //63:32
                       fs_pc            //31:0   
                       };

reg         buf_fs_inst_valid;
reg  [31:0] buf_fs_inst;

wire        tlb_ref;
wire        tlb_flush;
wire [31:0] ws_pc;
wire        ex;
wire        eret_flush;
wire [31:0] c0_epc;
assign {tlb_ref   , //67:67
        tlb_flush , //66:66
        ws_pc     , //65:34
        ex        , //33:33
        eret_flush, //32:32
        c0_epc      //31:0
       } = ws_to_fs_bus;

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = tlb_ref          ? 32'hbfc00200 :
                      ex               ? 32'hbfc00380 :
                      tlb_flush        ? ws_pc + 3'h4 :
                      eret_flush       ? c0_epc :
                      br_taken         ? br_target :
                      buf_nextpc_valid ? buf_nextpc :
                                         seq_pc;

// assign inst_addr_mapped = (nextpc[31:30] != 2'b10);
assign inst_addr_mapped = 1'b0;

always @(posedge clk) begin
    if (reset) begin
        buf_nextpc_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        buf_nextpc_valid <= 1'b0;
    end
    else if (!buf_nextpc_valid) begin
        buf_nextpc_valid <= 1'b1;
    end
    
    if (!buf_nextpc_valid || tlb_ref || ex || eret_flush || tlb_flush || br_taken) begin
        buf_nextpc <= nextpc;
    end
end

// exception: pre-IF
assign inst_tlb_ref     = inst_addr_mapped & ~s0_found;
assign inst_tlb_inv     = inst_addr_mapped & ~s0_v;

// IF stage
assign fs_ready_go    = (fs_inst_tlb_ref || fs_inst_tlb_inv) || (buf_fs_inst_valid || inst_data_ok);
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
        fs_inst_tlb_ref <= inst_tlb_ref;
        fs_inst_tlb_inv <= inst_tlb_inv;
    end
end

always @(posedge clk) begin
    if (reset) begin
        buf_fs_inst_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        buf_fs_inst_valid <= 1'b0;
    end
    else if (inst_data_ok) begin
        buf_fs_inst_valid <= 1'b1;
    end
    
    if (!buf_fs_inst_valid) begin
        buf_fs_inst <= fs_inst;
    end
end

always @(posedge clk) begin
    if (reset) begin
        buf_br <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        buf_br <= 1'b0;
    end
    else if (br) begin
        buf_br <= 1'b1;
    end
end

assign inst_req   = to_fs_valid && fs_allowin && !(inst_tlb_ref || inst_tlb_inv);
assign inst_size  = 2'h2;
assign inst_addr  = {inst_addr_mapped?s0_pfn:nextpc[31:12], nextpc[11:0]};

assign fs_inst    = buf_fs_inst_valid ? buf_fs_inst : 
                               (fs_ex ? 32'h0 : 
                                        inst_rdata);

// exception
assign fs_bd = br | buf_br;
assign fs_pc_ex = (fs_pc[1:0] != 2'b0);
assign fs_ex = fs_pc_ex || fs_inst_tlb_ref || fs_inst_tlb_inv;

endmodule

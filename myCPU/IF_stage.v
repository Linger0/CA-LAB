`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    //from ws: for exception
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus   ,
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

wire        br;
wire        br_taken;
wire [31:0] br_target;
assign {br,br_taken,br_target} = br_bus;

reg         buf_br;

wire        fs_bd;
wire        fs_ex;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_bd   ,
                       fs_ex   ,
                       fs_inst ,
                       fs_pc   };

reg         buf_fs_inst_valid;
reg  [31:0] buf_fs_inst;

wire        tlb_flush;
wire [31:0] ws_pc;
wire        ex;
wire        eret_flush;
wire [31:0] c0_epc;
assign {tlb_flush , //66:35
        ws_pc     , //34:34
        ex        , //33:33
        eret_flush, //32:32
        c0_epc      //31:0
       } = ws_to_fs_bus;

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = ex               ? 32'hbfc00380 :
                      tlb_flush        ? ws_pc + 3'h4 :
                      eret_flush       ? c0_epc :
                      br_taken         ? br_target :
                      buf_nextpc_valid ? buf_nextpc :
                                         seq_pc;

// IF stage
assign fs_ready_go    = buf_fs_inst_valid || inst_data_ok;
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
        buf_nextpc_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        buf_nextpc_valid <= 1'b0;
    end
    else if (!buf_nextpc_valid) begin
        buf_nextpc_valid <= 1'b1;
    end
    
    if (!buf_nextpc_valid || ex || eret_flush || tlb_flush || br_taken) begin
        buf_nextpc <= nextpc;
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

assign inst_req   = to_fs_valid && fs_allowin;
assign inst_size  = 2'h2;
assign inst_addr  = nextpc;

assign fs_inst    = buf_fs_inst_valid ? buf_fs_inst : inst_rdata;

// exception
assign fs_bd = br | buf_br;
assign fs_ex = (fs_pc[1:0] != 2'b0);

endmodule

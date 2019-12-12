`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to ds: for forwarding
    output [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,
    //exception
    output                         ms_to_es_ex   ,
    input                          ms_flush      ,
    //block tlbp
    output                         ms_to_es_mtc0 ,
    //from data sram-like
    input  [31:0] data_rdata,
    input         data_data_ok
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_tlb_ref;
wire        ms_tlb_flush;
wire        ms_tlbr_op;
wire        ms_tlbwi_op;
wire        ms_res_from_mem;
wire        ms_bd;
wire        ms_ex;
wire        ms_eret_flush;
wire        ms_mfc0_op;
wire        ms_mtc0_op;
wire [ 4:0] ms_excode;
wire [31:0] ms_badvaddr;
wire [ 4:0] ms_c0_addr;
wire [ 3:0] ms_mem_byte_d;
wire [31:0] ms_rt_value;
wire        ms_load_byte;
wire        ms_load_half;
wire        ms_load_signed;
wire        ms_load_left;
wire        ms_load_right;
wire        ms_load_word;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
assign {ms_tlb_ref     ,  //163:163
        ms_tlb_flush   ,  //162:162
        ms_tlbr_op     ,  //161:161
        ms_tlbwi_op    ,  //160:160
        ms_res_from_mem,  //159:159
        ms_bd          ,  //158:158
        ms_ex          ,  //157:157
        ms_eret_flush  ,  //156:156
        ms_mfc0_op     ,  //155:155
        ms_mtc0_op     ,  //154:154
        ms_excode      ,  //153:149
        ms_badvaddr    ,  //148:117
        ms_c0_addr     ,  //116:112
        ms_mem_byte_d  ,  //111:108
        ms_rt_value    ,  //107:76
        ms_load_byte   ,  //75:75
        ms_load_half   ,  //74:74
        ms_load_signed ,  //73:73
        ms_load_left   ,  //72:72
        ms_load_right  ,  //71:71
        ms_load_word   ,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] mem_lwl_result;
wire [31:0] mem_lwr_result;
wire [31:0] ms_final_result;

wire        ms_rf_we;
wire        ms_rf_wdata_valid;
assign ms_to_ds_bus = {ms_rf_we         ,  //38:38
                       ms_rf_wdata_valid,  //37:37
                       ms_dest          ,  //36:32
                       ms_final_result     //31:0
                      };

assign ms_to_ws_bus = {ms_tlb_ref     ,  //120:120
                       ms_tlb_flush   ,  //119:119
                       ms_tlbr_op     ,  //118:118
                       ms_tlbwi_op    ,  //117:117
                       ms_bd          ,  //116:116
                       ms_ex          ,  //115:115
                       ms_eret_flush  ,  //114:114
                       ms_mfc0_op     ,  //113:113
                       ms_mtc0_op     ,  //112:112
                       ms_excode      ,  //111:107
                       ms_badvaddr    ,  //106:75
                       ms_c0_addr     ,  //74:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = ms_ex || ~(ms_res_from_mem && ~data_data_ok);
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset || ms_flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

assign mem_result     = ({32{ms_mem_byte_d[0]}} & data_rdata)
                      | ({32{ms_mem_byte_d[1]}} & data_rdata[31:8])
                      | ({32{ms_mem_byte_d[2]}} & data_rdata[31:16])
                      | ({32{ms_mem_byte_d[3]}} & data_rdata[31:24]);
assign mem_lwl_result = ({32{ms_mem_byte_d[0]}} & {data_rdata[7:0],  ms_rt_value[23:0]})
                      | ({32{ms_mem_byte_d[1]}} & {data_rdata[15:0], ms_rt_value[15:0]})
                      | ({32{ms_mem_byte_d[2]}} & {data_rdata[23:0], ms_rt_value[7:0]})
                      | ({32{ms_mem_byte_d[3]}} &  data_rdata);
assign mem_lwr_result = ({32{ms_mem_byte_d[0]}} &                      data_rdata)
                      | ({32{ms_mem_byte_d[1]}} & {ms_rt_value[31:24], data_rdata[31:8]})
                      | ({32{ms_mem_byte_d[2]}} & {ms_rt_value[31:16], data_rdata[31:16]})
                      | ({32{ms_mem_byte_d[3]}} & {ms_rt_value[31:8],  data_rdata[31:24]});

assign ms_final_result = ms_load_byte  ? {{24{ms_load_signed&mem_result[7]}},  mem_result[7:0]} :
                         ms_load_half  ? {{16{ms_load_signed&mem_result[15]}}, mem_result[15:0]} :
                         ms_load_left  ? mem_lwl_result :
                         ms_load_right ? mem_lwr_result :
                         ms_load_word  ? mem_result :
                         ms_mtc0_op    ? ms_rt_value :
                                         ms_alu_result;

// to ds: for forwarding
assign ms_rf_we          = ms_valid&&ms_gr_we;
assign ms_rf_wdata_valid = ms_to_ws_valid&~ms_mfc0_op;

assign ms_to_es_ex   = ms_valid && (ms_ex || ms_eret_flush || ms_tlb_flush);
assign ms_to_es_mtc0 = ms_valid && ms_mtc0_op;

endmodule
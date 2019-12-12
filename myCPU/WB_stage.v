`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD  -1:0] ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD  -1:0] ws_to_rf_bus  ,
    //to ds
    output [`WS_TO_DS_BUS_WD  -1:0] ws_to_ds_bus  ,
    //exception
    output                          ws_flush      ,
    output                          has_int       ,
    output [`WS_TO_FS_BUS_WD  -1:0] ws_to_fs_bus  ,
    //block tlbp
    output                          ws_to_es_mtc0 ,
    //tlb
    input  [`ES_TO_TLB_BUS_WD -1:0] es_to_tlb_bus ,
    output [`TLB_TO_ES_BUS_WD -1:0] tlb_to_es_bus ,
    input  [`FS_TO_TLB_BUS_WD -1:0] fs_to_tlb_bus ,
    output [`TLB_TO_FS_BUS_WD -1:0] tlb_to_fs_bus ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_tlb_ref;
wire        ws_tlb_flush;
wire        ws_tlbr_op;
wire        ws_tlbwi_op;
wire        ws_bd;
wire        ws_ex;
wire        ws_eret_flush;
wire        ws_mfc0_op;
wire        ws_mtc0_op;
wire [ 4:0] ws_excode;
wire [31:0] ws_badvaddr;
wire [ 4:0] ws_c0_addr;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
assign {ws_tlb_ref     ,  //120:120
        ws_tlb_flush   ,  //119:119
        ws_tlbr_op     ,  //118:118
        ws_tlbwi_op    ,  //117:117
        ws_bd          ,  //116:116
        ws_ex          ,  //115:115
        ws_eret_flush  ,  //114:114
        ws_mfc0_op     ,  //113:113
        ws_mtc0_op     ,  //112:112
        ws_excode      ,  //111:107
        ws_badvaddr    ,  //106:75
        ws_c0_addr     ,  //74:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

wire        tlb_flush;

wire        ex;
wire        tlb_ref;
wire        eret_flush;
wire        mtc0_we;
wire [31:0] ws_c0_wdata;
wire [31:0] ws_c0_rdata;
wire        count_eq_compare;
wire [ 5:0] ext_int_in;

// cp0
wire [31:0] c0_status;
wire [31:0] c0_cause;
wire [31:0] c0_epc;
wire [31:0] c0_badvaddr;
wire [31:0] c0_count;
wire [31:0] c0_compare;
wire [31:0] c0_entryhi;
wire [31:0] c0_entrylo0;
wire [31:0] c0_entrylo1;
wire [31:0] c0_index;

// search port 0
wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire [ 7:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_d;
wire        s0_v;
// search port 1
wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire  [7:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v;
// write port
wire        we;
wire [ 3:0] w_index;
wire [18:0] w_vpn2;
wire [ 7:0] w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [ 2:0] w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [ 2:0] w_c1;
wire        w_d1;
wire        w_v1;
// read port
wire [ 3:0] r_index;
wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire        r_d1;
wire        r_v1;

assign ws_to_fs_bus = {tlb_ref   , //67:67
                       tlb_flush , //66:66
                       ws_pc     , //65:34
                       ex        , //33:33
                       eret_flush, //32:32
                       c0_epc      //31:0
                      };

wire        ws_rf_wdata_valid;
assign ws_to_ds_bus = {rf_we            ,  //38:38
                       ws_rf_wdata_valid,  //37:37
                       ws_dest          ,  //36:32
                       rf_wdata            //31:0
                      };

wire        tlbp_op;
wire [18:0] data_addr_vpn2;
assign {tlbp_op       ,
        data_addr_vpn2,
        s1_odd_page
       } = es_to_tlb_bus;
assign {s0_vpn2    ,
        s0_odd_page
       } = fs_to_tlb_bus;
       
assign tlb_to_es_bus = {s1_found,
                        s1_pfn  ,
                        s1_c    ,
                        s1_d    ,
                        s1_v    
                       };
assign tlb_to_fs_bus = {s0_found,
                        s0_pfn  ,
                        s0_c    ,
                        s0_v    
                       };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset || ws_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid&&!ws_ex;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_mfc0_op ? ws_c0_rdata : ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

// to ds: for forwarding
assign ws_rf_wdata_valid = ws_valid&&ws_ready_go;

// to CP0
assign ex          = ws_valid && ws_ex;
assign eret_flush  = ws_valid && ws_eret_flush;
assign mtc0_we     = ws_valid && ws_mtc0_op && !ws_ex;
assign ws_c0_wdata = ws_final_result;
assign ws_c0_rdata = ({32{ws_c0_addr==`CR_STATUS}}   & c0_status)
                   | ({32{ws_c0_addr==`CR_CAUSE}}    & c0_cause)
                   | ({32{ws_c0_addr==`CR_EPC}}      & c0_epc)
                   | ({32{ws_c0_addr==`CR_BADVADDR}} & c0_badvaddr)
                   | ({32{ws_c0_addr==`CR_COUNT}}    & c0_count)
                   | ({32{ws_c0_addr==`CR_COMPARE}}  & c0_compare)
                   | ({32{ws_c0_addr==`CR_ENTRYHI}}  & c0_entryhi)
                   | ({32{ws_c0_addr==`CR_ENTRYLO0}} & c0_entrylo0)
                   | ({32{ws_c0_addr==`CR_ENTRYLO1}} & c0_entrylo1)
                   | ({32{ws_c0_addr==`CR_INDEX}}    & c0_index);

assign ext_int_in       = 0;
assign count_eq_compare = (c0_count == c0_compare);

// to TLB
assign s0_asid = c0_entryhi[7:0];
assign s1_vpn2 = tlbp_op ? c0_entryhi[31:13] : data_addr_vpn2;
assign s1_asid = c0_entryhi[7:0];
assign we      = ws_valid&&ws_tlbwi_op;
assign w_index = c0_index[3:0];
assign w_vpn2  = c0_entryhi[31:13];
assign w_asid  = c0_entryhi[7:0];
assign w_g     = c0_entrylo0[0] & c0_entrylo1[0];
assign w_pfn0  = c0_entrylo0[25:6];
assign w_c0    = c0_entrylo0[5:3];
assign w_d0    = c0_entrylo0[2];
assign w_v0    = c0_entrylo0[1];
assign w_pfn1  = c0_entrylo1[25:6];
assign w_c1    = c0_entrylo1[5:3];
assign w_d1    = c0_entrylo1[2];
assign w_v1    = c0_entrylo1[1];
assign r_index = c0_index[3:0];

assign tlb_flush     = ws_valid&&ws_tlb_flush;
assign ws_to_es_mtc0 = mtc0_we;

//exception
assign ws_flush = ws_valid && (ws_ex || ws_eret_flush || ws_tlb_flush);
assign has_int  = (c0_cause[15:8] & c0_status[15:8])!=8'h00 && c0_status[0]==1'b1 && c0_status[1]==1'b0;
assign tlb_ref  = ws_valid && ws_tlb_ref;

cp0 u_cp0(
    .clk(clk),
    .reset(reset),
    .mtc0_we(mtc0_we),
    .c0_addr(ws_c0_addr),
    .c0_wdata(ws_c0_wdata),
    .ex(ex),
    .eret_flush(eret_flush),
    .c0_status(c0_status),
    .bd(ws_bd),
    .count_eq_compare(count_eq_compare),
    .ext_int_in(ext_int_in),
    .excode(ws_excode),
    .c0_cause(c0_cause),
    .pc(ws_pc),
    .c0_epc(c0_epc),
    .badvaddr(ws_badvaddr),
    .c0_badvaddr(c0_badvaddr),
    .c0_count(c0_count),
    .c0_compare(c0_compare),
    .c0_entryhi(c0_entryhi),
    .tlbr_op(ws_tlbr_op),
    .r_vpn2(r_vpn2),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_pfn0(r_pfn0),
    .r_c0(r_c0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_pfn1(r_pfn1),
    .r_c1(r_c1),
    .r_d1(r_d1),
    .r_v1(r_v1),
    .c0_entrylo0(c0_entrylo0),
    .c0_entrylo1(c0_entrylo1),
    .tlbp_op(tlbp_op),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .c0_index(c0_index)
);

tlb #(.TLBNUM(16)) u_tlb(
    .clk(clk),
    .s0_vpn2(s0_vpn2),
    .s0_odd_page(s0_odd_page),
    .s0_asid(s0_asid),
    .s0_found(s0_found),
    .s0_index(s0_index),
    .s0_pfn(s0_pfn),
    .s0_c(s0_c),
    .s0_d(s0_d),
    .s0_v(s0_v),
    .s1_vpn2(s1_vpn2),
    .s1_odd_page(s1_odd_page),
    .s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_pfn(s1_pfn),
    .s1_c(s1_c),
    .s1_d(s1_d),
    .s1_v(s1_v),
    .we(we),
    .w_index(w_index),
    .w_vpn2(w_vpn2),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_pfn0(w_pfn0),
    .w_c0(w_c0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_pfn1(w_pfn1),
    .w_c1(w_c1),
    .w_d1(w_d1),
    .w_v1(w_v1),
    .r_index(r_index),
    .r_vpn2(r_vpn2),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_pfn0(r_pfn0),
    .r_c0(r_c0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_pfn1(r_pfn1),
    .r_c1(r_c1),
    .r_d1(r_d1),
    .r_v1(r_v1)
);

endmodule

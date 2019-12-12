`include "mycpu.h"

module exe_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    input                           ms_allowin    ,
    output                          es_allowin    ,
    //from ds
    input                           ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD  -1:0] ds_to_es_bus  ,
    //to ms
    output                          es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD  -1:0] es_to_ms_bus  ,
    //to ds: for forwarding
    output [`ES_TO_DS_BUS_WD  -1:0] es_to_ds_bus  ,
    //exception
    input                           ms_to_es_ex   ,
    input                           es_flush      ,
    //block tlbp
    input                           ms_to_es_mtc0 ,
    input                           ws_to_es_mtc0 ,
    //tlb
    output [`ES_TO_TLB_BUS_WD -1:0] es_to_tlb_bus,
    input  [`TLB_TO_ES_BUS_WD -1:0] tlb_to_es_bus,
    //data sram-like 
    output        data_req    ,
    output        data_wr     ,
    output [ 1:0] data_size   ,
    output [31:0] data_addr   ,
    output [ 3:0] data_wstrb  ,
    output [31:0] data_wdata  ,
    input         data_addr_ok
);
// HI & LO
reg  [31:0] hi      ;
reg  [31:0] lo      ;
wire [31:0] hi_wdata;
wire [31:0] lo_wdata;

reg         es_valid        ;
wire        es_ready_go     ;

reg         div_is_finished ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        es_inst_tlb_inv ;
wire        es_inst_tlb_ref ;
wire        es_tlb_flush    ;
wire        es_tlbr_op      ;
wire        es_tlbwi_op     ;
wire        es_tlbp_op      ;
wire        es_bd           ;
wire        es_pc_ex        ;
wire        es_int          ;
wire        es_check_ov     ;
wire        es_ri           ;
wire        es_old_ex       ;
wire        es_eret_flush   ;
wire        es_mfc0_op      ;
wire        es_mtc0_op      ;
wire        es_break_op     ;
wire        es_syscall_op   ;
wire [ 4:0] es_c0_addr      ;
wire        es_st_byte      ;
wire        es_st_half      ;
wire        es_st_left      ;
wire        es_st_right     ;
wire        es_load_byte    ;
wire        es_load_half    ;
wire        es_load_signed  ;
wire        es_load_left    ;
wire        es_load_right   ;
wire        es_mul_op       ;
wire        es_div_op       ;
wire        es_md_signed    ;
wire        es_src1_is_hi   ;
wire        es_src1_is_lo   ;
wire        es_hi_we        ;
wire        es_lo_we        ;
wire [11:0] es_alu_op       ;
wire        es_load_word    ;
wire        es_src1_is_sa   ;  
wire        es_src1_is_pc   ;
wire        es_src2_is_0eimm;
wire        es_src2_is_imm  ; 
wire        es_src2_is_8    ;
wire        es_gr_we        ;
wire        es_mem_we       ;
wire [ 4:0] es_dest         ;
wire [15:0] es_imm          ;
wire [31:0] es_rs_value     ;
wire [31:0] es_rt_value     ;
wire [31:0] es_pc           ;
assign {es_inst_tlb_inv ,  //174:174
        es_inst_tlb_ref ,  //173:173
        es_tlb_flush    ,  //172:172
        es_tlbr_op      ,  //171:171
        es_tlbwi_op     ,  //170:170
        es_tlbp_op      ,  //169:169
        es_bd           ,  //168:168
        es_pc_ex        ,  //167:167
        es_int          ,  //166:166
        es_check_ov     ,  //165:165
        es_ri           ,  //164:164
        es_old_ex       ,  //163:163
        es_eret_flush   ,  //162:162
        es_mfc0_op      ,  //161:161
        es_mtc0_op      ,  //160:160
        es_break_op     ,  //159:159
        es_syscall_op   ,  //158:158
        es_c0_addr      ,  //157:153
        es_st_byte      ,  //152:152
        es_st_half      ,  //151:151
        es_st_left      ,  //150:150
        es_st_right     ,  //149:149
        es_load_byte    ,  //148:148
        es_load_half    ,  //147:147
        es_load_signed  ,  //146:146
        es_load_left    ,  //145:145
        es_load_right   ,  //144:144
        es_mul_op       ,  //143:143
        es_div_op       ,  //142:142
        es_md_signed    ,  //141:141
        es_src1_is_hi   ,  //140:140
        es_src1_is_lo   ,  //139:139
        es_hi_we        ,  //138:138
        es_lo_we        ,  //137:137
        es_alu_op       ,  //136:125
        es_load_word    ,  //124:124
        es_src1_is_sa   ,  //123:123
        es_src1_is_pc   ,  //122:122
        es_src2_is_0eimm,  //121:121
        es_src2_is_imm  ,  //120:120
        es_src2_is_8    ,  //119:119
        es_gr_we        ,  //118:118
        es_mem_we       ,  //117:117
        es_dest         ,  //116:112
        es_imm          ,  //111:96
        es_rs_value     ,  //95 :64
        es_rt_value     ,  //63 :32
        es_pc              //31 :0
        } = ds_to_es_bus_r;

wire [ 3:0] es_mem_byte_d;
wire [ 3:0] es_dram_wen;
wire [31:0] swl_result;
wire [31:0] swr_result;

wire        es_res_from_mem;

wire        ds_div_op;
assign ds_div_op = ds_to_es_bus[142];

wire [31:0] es_alu_src1  ;
wire [31:0] es_alu_src2  ;
wire [31:0] es_alu_result;
wire        es_alu_ov    ;

wire [31:0] es_mul_x   ;
wire [31:0] es_mul_y   ;
wire [63:0] es_mul_prod;

reg         es_div_dividend_tvalid;
reg         es_div_divisor_tvalid ;
wire [31:0] es_div_dividend_tdata ;
wire [31:0] es_div_divisor_tdata  ;
wire        es_div_dividend_tready;
wire        es_div_divisor_tready ;
wire        es_div_dout_tvalid    ;
wire [63:0] es_div_dout_tdata     ;

wire        es_rf_we         ;
wire        es_rf_wdata_valid;
assign es_to_ds_bus = {es_rf_we         ,  //38:38
                       es_rf_wdata_valid,  //37:37
                       es_dest          ,  //36:32
                       es_alu_result       //31:0
                      };

wire        data_addr_mapped;
wire        data_tlb_ref;
wire        data_tlb_inv;

wire        es_do_tlbp;
wire [19:0] data_addr_vpn;
assign es_to_tlb_bus = {es_do_tlbp,
                        data_addr_vpn};
assign data_addr_vpn = es_alu_result[31:12];

wire        s1_found;
wire [19:0] data_addr_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v;
assign {s1_found     ,
        data_addr_pfn,
        s1_c         ,
        s1_d         ,
        s1_v
       } = tlb_to_es_bus;

wire        es_ex;
wire        es_tlbl;
wire        es_tlbs;
wire        es_mod;
wire        es_adel;
wire        es_ades;
wire        es_ov;
wire [ 4:0] es_excode;
wire [31:0] es_badvaddr;

wire        es_tlb_ref;

assign es_to_ms_bus = {es_tlb_ref     ,  //163:163
                       es_tlb_flush   ,  //162:162
                       es_tlbr_op     ,  //161:161
                       es_tlbwi_op    ,  //160:160
                       es_res_from_mem,  //159:159
                       es_bd          ,  //158:158
                       es_ex          ,  //157:157
                       es_eret_flush  ,  //156:156
                       es_mfc0_op     ,  //155:155
                       es_mtc0_op     ,  //154:154
                       es_excode      ,  //153:149
                       es_badvaddr    ,  //148:117
                       es_c0_addr     ,  //116:112
                       es_mem_byte_d  ,  //111:108
                       es_rt_value    ,  //107:76
                       es_load_byte   ,  //75:75
                       es_load_half   ,  //74:74
                       es_load_signed ,  //73:73
                       es_load_left   ,  //72:72
                       es_load_right  ,  //71:71
                       es_load_word   ,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = es_ex || ~(es_div_op && ~(es_div_dout_tvalid || div_is_finished)) 
                              && ~((es_mem_we || es_res_from_mem) && ~data_addr_ok)
                              && ~(es_tlbp_op && ~es_do_tlbp);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset || es_flush) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

// HI & LO: write
always @(posedge clk) begin
    if (es_to_ms_valid && es_hi_we && !es_ex && !div_is_finished)
        hi <= hi_wdata;
    if (es_to_ms_valid && es_lo_we && !es_ex && !div_is_finished)
        lo <= lo_wdata;
end

// to div: tvalid
always @(posedge clk) begin
    if (ds_to_es_valid && es_allowin) begin
        es_div_dividend_tvalid <= ds_div_op && ~es_ex;
    end
    else if (es_div_dividend_tvalid) begin
        es_div_dividend_tvalid <= ~es_div_dividend_tready;
    end

    if (ds_to_es_valid && es_allowin) begin
        es_div_divisor_tvalid <= ds_div_op && ~es_ex;
    end
    else if (es_div_divisor_tvalid) begin
        es_div_divisor_tvalid <= ~es_div_divisor_tready;
    end
end

// div_is_finished
always @(posedge clk) begin
    if (reset) begin
        div_is_finished <= 1'b0;
    end
    else if (ds_to_es_valid && es_allowin) begin
        div_is_finished <= 1'b0;
    end
    else if (es_div_dout_tvalid) begin
        div_is_finished <= 1'b1;
    end
end

assign es_alu_src1 = es_src1_is_hi  ? hi :
                     es_src1_is_lo  ? lo :
                     es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_0eimm ? {16'b0, es_imm[15:0]} :
                     es_src2_is_imm   ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_8     ? 32'd8 :
                                        es_rt_value;
alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .alu_ov     (es_alu_ov)
    );

assign es_mem_byte_d[0] = (es_alu_result[1:0] == 0);
assign es_mem_byte_d[1] = (es_alu_result[1:0] == 1);
assign es_mem_byte_d[2] = (es_alu_result[1:0] == 2);
assign es_mem_byte_d[3] = (es_alu_result[1:0] == 3);

assign es_dram_wen = es_st_byte  ? es_mem_byte_d                                        :
                     es_st_half  ? {{2{es_mem_byte_d[2'h2]}}, {2{es_mem_byte_d[2'h0]}}} :
                     es_st_left  ? {es_mem_byte_d[2'h3], 
                                    es_alu_result[1]   ,
                                   ~es_mem_byte_d[2'h0], 
                                    1'b1}                                               :
                     es_st_right ? {1'b1               , 
                                   ~es_mem_byte_d[2'h3],
                                   ~es_alu_result[1]   ,
                                    es_mem_byte_d[2'h0]}                                :
                    /*inst_sw*/     4'b1111;
assign swl_result  = ({32{es_mem_byte_d[2'h0]}} & es_rt_value[31:24])
                   | ({32{es_mem_byte_d[2'h1]}} & es_rt_value[31:16])
                   | ({32{es_mem_byte_d[2'h2]}} & es_rt_value[31:8])
                   | ({32{es_mem_byte_d[2'h3]}} & es_rt_value);
assign swr_result  = ({32{es_mem_byte_d[2'h0]}} & es_rt_value)
                   | ({32{es_mem_byte_d[2'h1]}} & {es_rt_value[23:0], 8'd0})
                   | ({32{es_mem_byte_d[2'h2]}} & {es_rt_value[15:0], 16'd0})
                   | ({32{es_mem_byte_d[2'h3]}} & {es_rt_value[7:0], 24'd0});

assign es_res_from_mem = es_load_byte | es_load_half | es_load_left | es_load_right | es_load_word;

// to data sram-like
assign data_req   = es_valid&&!es_ex && (es_mem_we || es_res_from_mem);
assign data_wr    = es_mem_we;
assign data_size  = 2'h2;
assign data_wstrb = es_dram_wen;
assign data_addr  = {data_addr_mapped?data_addr_pfn:es_alu_result[31:12], es_alu_result[11:0]};
assign data_wdata = es_st_byte  ? {4{es_rt_value[7:0]}} : 
                    es_st_half  ? {2{es_rt_value[15:0]}} : 
                    es_st_left  ? swl_result :
                    es_st_right ? swr_result :
                                  es_rt_value;

assign data_addr_mapped = (es_alu_result[31:30] != 2'b10);

// to ds: for forwarding
assign es_rf_we          = es_valid&&es_gr_we;
assign es_rf_wdata_valid = es_to_ms_valid&&~es_mfc0_op
                         &&~es_load_byte&&~es_load_half&&~es_load_word&&~es_load_left&&~es_load_right;

// mul & div
assign es_mul_x = es_rs_value;
assign es_mul_y = es_rt_value;
mul u_mul(
    .mul_x      (es_mul_x),
    .mul_y      (es_mul_y),
    .mul_signed (es_md_signed),
    .mul_prod   (es_mul_prod)
);
assign es_div_dividend_tdata = es_rs_value;
assign es_div_divisor_tdata  = es_rt_value;
div u_div(
    .div_clk            (clk),
    .div_dividend_tdata (es_div_dividend_tdata),
    .div_divisor_tdata  (es_div_divisor_tdata),
    .div_signed         (es_md_signed),
    .div_dividend_tvalid(es_div_dividend_tvalid),
    .div_dividend_tready(es_div_dividend_tready),
    .div_divisor_tvalid (es_div_divisor_tvalid),
    .div_divisor_tready (es_div_divisor_tready),
    .div_dout_tvalid    (es_div_dout_tvalid),
    .div_dout_tdata     (es_div_dout_tdata)
    );
    
// HI & LO: wdata
assign hi_wdata = es_mul_op ? es_mul_prod[63:32] :
                  es_div_op ? es_div_dout_tdata[31:0] :
                              es_rs_value;
assign lo_wdata = es_mul_op ? es_mul_prod[31:0] :
                  es_div_op ? es_div_dout_tdata[63:32] :
                              es_rs_value;

// exception
assign es_ex     = es_old_ex | es_adel | es_ades | es_ov | es_tlbl | es_tlbs | es_mod | ms_to_es_ex | es_flush;
assign es_adel   = es_load_word&&~es_mem_byte_d[2'h0]   /* inst_lw */
                || es_load_half&&es_alu_result[0];      /* inst_lh */
assign es_ades   = es_mem_we&&~es_st_byte&&~es_st_half&&~es_st_left&&~es_st_right&&~es_mem_byte_d[2'h0] /* inst_sw */
                || es_st_half&&es_alu_result[0];                                                        /* inst_sh */
assign es_ov     = es_check_ov&&es_alu_ov;
assign es_tlbl   = es_res_from_mem&&(data_tlb_ref || data_tlb_inv);
assign es_tlbs   = es_mem_we&&(data_tlb_ref || data_tlb_inv);
assign es_mod    = es_mem_we&&data_addr_mapped&&~s1_d;
assign es_excode = es_int          ? `EX_INT :
                   es_pc_ex        ? `EX_ADEL :
                   es_inst_tlb_ref ? `EX_TLBL :
                   es_inst_tlb_inv ? `EX_TLBL :
                   es_ri           ? `EX_RI :
                   es_syscall_op   ? `EX_SYS :
                   es_break_op     ? `EX_BP :
                   es_ov           ? `EX_OV :
                   es_adel         ? `EX_ADEL :
                   es_ades         ? `EX_ADES : 
                   es_tlbl         ? `EX_TLBL :
                   es_tlbs         ? `EX_TLBS :
                   es_mod          ? `EX_MOD : 5'h0;
assign es_badvaddr = (es_pc_ex|es_inst_tlb_ref|es_inst_tlb_inv) ? es_pc : es_alu_result;
assign es_tlb_ref  = (es_excode==`EX_TLBL||es_excode==`EX_TLBS) && (es_inst_tlb_ref||data_tlb_ref);

assign data_tlb_ref = (es_res_from_mem|es_mem_we) & data_addr_mapped & ~s1_found;
assign data_tlb_inv = (es_res_from_mem|es_mem_we) & data_addr_mapped & ~s1_v;

// to tlb
assign es_do_tlbp = es_valid&&es_tlbp_op&&!es_ex&&!ms_to_es_mtc0&&!ws_to_es_mtc0;

endmodule

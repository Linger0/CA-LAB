`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //from es/ms/ws: for forwarding
    input  [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus  ,
    input  [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,
    input  [`WS_TO_DS_BUS_WD -1:0] ws_to_ds_bus  ,
    //exception
    input                          ds_flush      ,
    input                          ds_has_int
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire        ds_inst_tlb_inv;
wire        ds_inst_tlb_ref;
wire        ds_pc_ex;
wire        ds_bd;
wire        ds_old_ex;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst_tlb_inv, //68:68
        ds_inst_tlb_ref, //67:67
        ds_pc_ex       , //66:66
        ds_bd          , //65:65
        ds_old_ex      , //64:64
        ds_inst        , //63:32
        ds_pc            //31:0  
        } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br;
wire        br_taken;
wire [31:0] br_target;
assign br_bus = {br,br_taken,br_target};

wire        tlb_flush;
wire        tlbr_op;
wire        tlbwi_op;
wire        tlbp_op;
wire        check_ov;
wire        ds_ri;
wire        mfc0_op;
wire        mtc0_op;
wire        break_op;
wire        syscall_op;
wire [ 4:0] c0_addr;
wire        ds_ex;
wire        ds_eret_flush;
wire        st_byte;
wire        st_half;
wire        st_left;
wire        st_right;
wire        load_byte;
wire        load_half;
wire        load_signed;
wire        load_left;
wire        load_right;
wire        mul_op;
wire        div_op;
wire        md_signed;
wire        src1_is_hi;
wire        src1_is_lo;
wire        hi_we;
wire        lo_we;
wire [11:0] alu_op;
wire        load_word;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_0eimm;
wire        src2_is_imm;
wire        src2_is_8;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
assign ds_to_es_bus = {ds_inst_tlb_inv,  //174:174
                       ds_inst_tlb_ref,  //173:173
                       tlb_flush      ,  //172:172
                       tlbr_op        ,  //171:171
                       tlbwi_op       ,  //170:170
                       tlbp_op        ,  //169:169
                       ds_bd          ,  //168:168
                       ds_pc_ex       ,  //167:167
                       ds_has_int     ,  //166:166
                       check_ov       ,  //165:165
                       ds_ri          ,  //164:164
                       ds_ex          ,  //163:163
                       ds_eret_flush  ,  //162:162 
                       mfc0_op        ,  //161:161
                       mtc0_op        ,  //160:160
                       break_op       ,  //159:159
                       syscall_op     ,  //158:158
                       c0_addr        ,  //157:153
                       st_byte        ,  //152:152
                       st_half        ,  //151:151
                       st_left        ,  //150:150
                       st_right       ,  //149:149
                       load_byte      ,  //148:148
                       load_half      ,  //147:147
                       load_signed    ,  //146:146
                       load_left      ,  //145:145
                       load_right     ,  //144:144
                       mul_op         ,  //143:143
                       div_op         ,  //142:142
                       md_signed      ,  //141:141
                       src1_is_hi     ,  //140:140
                       src1_is_lo     ,  //139:139
                       hi_we          ,  //138:138
                       lo_we          ,  //137:137
                       alu_op         ,  //136:125
                       load_word      ,  //124:124
                       src1_is_sa     ,  //123:123
                       src1_is_pc     ,  //122:122
                       src2_is_0eimm  ,  //121:121
                       src2_is_imm    ,  //120:120
                       src2_is_8      ,  //119:119
                       gr_we          ,  //118:118
                       mem_we         ,  //117:117
                       dest           ,  //116:112
                       imm            ,  //111:96
                       rs_value       ,  //95 :64
                       rt_value       ,  //63 :32
                       ds_pc             //31 :0
                      };

wire        inst_nop;
wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
wire        inst_mfc0;
wire        inst_mtc0;
wire        inst_eret;
wire        inst_syscall;
wire        inst_break;
wire        inst_tlbr;
wire        inst_tlbwi;
wire        inst_tlbp;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_gtz;
wire        rs_ltz;

// from es/ms/ws
wire        from_es_gr_we;
wire        from_es_valid;
wire [ 4:0] from_es_dest;
wire [31:0] from_es_result;
assign {from_es_gr_we ,  //38:38
        from_es_valid ,  //37:37
        from_es_dest  ,  //36:32
        from_es_result   //31:0
       } = es_to_ds_bus;
       
wire        from_ms_gr_we;
wire        from_ms_valid;
wire [ 4:0] from_ms_dest;
wire [31:0] from_ms_result;
assign {from_ms_gr_we ,  //38:38
        from_ms_valid ,  //37:37
        from_ms_dest  ,  //36:32
        from_ms_result   //31:0
       } = ms_to_ds_bus;
       
wire        from_ws_gr_we;
wire        from_ws_valid;
wire [ 4:0] from_ws_dest;
wire [31:0] from_ws_result;
assign {from_ws_gr_we ,  //38:38
        from_ws_valid ,  //37:37
        from_ws_dest  ,  //36:32
        from_ws_result   //31:0
       } = ws_to_ds_bus;

wire        rs_in_es;
wire        rt_in_es;
wire        rs_in_ms;
wire        rt_in_ms;
wire        rs_in_ws;
wire        rt_in_ws;

reg         buf_flush;

assign ds_ready_go    = ~((rs_in_es || rt_in_es) && ~from_es_valid
                       || (rs_in_ms || rt_in_ms) && ~from_ms_valid
                       || (rs_in_ws || rt_in_ws) && ~from_ws_valid);
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset || ds_flush || buf_flush) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        buf_flush <= 1'b0;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        buf_flush <= 1'b0;
    end
    else if (ds_flush) begin
        buf_flush <= 1'b1;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_nop     = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_addu    = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu    = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt     = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu    = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and     = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or      = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor     = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor     = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll     = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl     = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra     = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu   = op_d[6'h09];
assign inst_lui     = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw      = op_d[6'h23];
assign inst_sw      = op_d[6'h2b];
assign inst_beq     = op_d[6'h04];
assign inst_bne     = op_d[6'h05];
assign inst_jal     = op_d[6'h03];
assign inst_jr      = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_add     = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi    = op_d[6'h08];
assign inst_sub     = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti    = op_d[6'h0a];
assign inst_sltiu   = op_d[6'h0b];
assign inst_andi    = op_d[6'h0c];
assign inst_ori     = op_d[6'h0d];
assign inst_xori    = op_d[6'h0e];
assign inst_sllv    = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav    = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv    = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_mult    = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu   = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];
assign inst_div     = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu    = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mfhi    = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo    = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi    = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtlo    = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_bgez    = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz    = op_d[6'h07] & rt_d[5'h00];
assign inst_blez    = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz    = op_d[6'h01] & rt_d[5'h00];
assign inst_j       = op_d[6'h02];
assign inst_bltzal  = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal  = op_d[6'h01] & rt_d[5'h11];
assign inst_jalr    = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_lb      = op_d[6'h20];
assign inst_lbu     = op_d[6'h24];
assign inst_lh      = op_d[6'h21];
assign inst_lhu     = op_d[6'h25];
assign inst_lwl     = op_d[6'h22];
assign inst_lwr     = op_d[6'h26];
assign inst_sb      = op_d[6'h28];
assign inst_sh      = op_d[6'h29];
assign inst_swl     = op_d[6'h2a];
assign inst_swr     = op_d[6'h2e];
assign inst_mfc0    = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00];
assign inst_mtc0    = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00];
assign inst_eret    = op_d[6'h10] & func_d[6'h18] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbr    = op_d[6'h10] & func_d[6'h01] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbwi   = op_d[6'h10] & func_d[6'h02] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbp    = op_d[6'h10] & func_d[6'h08] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_syscall = op_d[6'h00] & func_d[6'h0c];
assign inst_break   = op_d[6'h00] & func_d[6'h0d];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw   | inst_sw     | inst_jal    | inst_add 
                  | inst_addi | inst_mfhi  | inst_mflo | inst_bltzal | inst_bgezal | inst_jalr 
                  | inst_lb   | inst_lbu   | inst_lh   | inst_lhu    | inst_lwl    | inst_lwr
                  | inst_sb   | inst_sh    | inst_swl  | inst_swr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;

assign tlb_flush     = inst_tlbwi | inst_tlbr;
assign tlbr_op       = inst_tlbr;
assign tlbwi_op      = inst_tlbwi;
assign tlbp_op       = inst_tlbp;
assign check_ov      = inst_add | inst_addi | inst_sub;
assign mfc0_op       = inst_mfc0;
assign mtc0_op       = inst_mtc0;
assign break_op      = inst_break;
assign syscall_op    = inst_syscall;
assign ds_eret_flush = inst_eret;
assign st_byte       = inst_sb;
assign st_half       = inst_sh;
assign st_left       = inst_swl;
assign st_right      = inst_swr;
assign load_byte     = inst_lb | inst_lbu;
assign load_half     = inst_lh | inst_lhu;
assign load_signed   = inst_lb | inst_lh;
assign load_left     = inst_lwl;
assign load_right    = inst_lwr;
assign load_word     = inst_lw;
assign mul_op        = inst_mult | inst_multu;
assign div_op        = inst_div | inst_divu;
assign md_signed     = inst_div | inst_mult;
assign src1_is_hi    = inst_mfhi;
assign src1_is_lo    = inst_mflo;
assign src1_is_sa    = inst_sll | inst_srl | inst_sra;
assign src1_is_pc    = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign src2_is_0eimm = inst_andi | inst_ori | inst_xori;
assign src2_is_imm   = inst_addiu | inst_lui | inst_lw  | inst_sw  | inst_addi | inst_slti | inst_sltiu | inst_lb | inst_lbu 
                     | inst_lh    | inst_lhu | inst_lwl | inst_lwr | inst_sb   | inst_sh   | inst_swl   | inst_swr;
assign src2_is_8     = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign dst_is_r31    = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt     = inst_addiu | inst_lui | inst_lw  | inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori 
                     | inst_xori  | inst_lb  | inst_lbu | inst_lh   | inst_lhu  | inst_lwl   | inst_lwr  | inst_mfc0;
assign hi_we         = inst_mthi | inst_mult | inst_multu | inst_div | inst_divu;
assign lo_we         = inst_mtlo | inst_mult | inst_multu | inst_div | inst_divu;
assign gr_we         = ~inst_sw   & ~inst_beq   & ~inst_bne  & ~inst_jr   & ~inst_mult & ~inst_multu   & ~inst_div   & ~inst_divu 
                     & ~inst_mthi & ~inst_mtlo  & ~inst_bgtz & ~inst_bgez & ~inst_bltz & ~inst_blez    & ~inst_j     & ~inst_sb    
                     & ~inst_sh   & ~inst_swl   & ~inst_swr  & ~inst_mtc0 & ~inst_eret & ~inst_syscall & ~inst_break & ~inst_tlbp
                     & ~inst_tlbr & ~inst_tlbwi & ~inst_nop; 
                     /* attention: exclude no write-back instruction */
assign mem_we        = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;

assign c0_addr       = rd;
assign dest          = dst_is_r31 ? 5'd31 :
                       dst_is_rt  ? rt    : 
                                    rd;

// exception
assign ds_ex    = ds_old_ex | syscall_op | break_op | ds_ri | ds_has_int;
assign ds_ri    = gr_we     & ~dst_is_rt  & ~src2_is_8  & ~inst_addu & ~inst_subu & ~inst_slt  & ~inst_sltu
                & ~inst_and & ~inst_or    & ~inst_xor   & ~inst_nor  & ~inst_sll  & ~inst_srl  & ~inst_sra
                & ~inst_add & ~inst_sub   & ~inst_sllv  & ~inst_srav & ~inst_srlv & ~inst_mfhi & ~inst_mflo;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

/* forwarding
 * attention: exclude no read-rs/rt instructions */
assign rs_in_es = ~inst_jal && ~inst_j && ~inst_mtc0 && ~inst_syscall && ~inst_eret && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rs != 0) && from_es_gr_we && (from_es_dest == rs);
assign rt_in_es = (inst_lwl || inst_lwr || ~inst_jal && ~inst_j && ~inst_syscall && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rt != 0) && ~dst_is_rt) && from_es_gr_we && (from_es_dest == rt);
assign rs_in_ms = ~inst_jal && ~inst_j && ~inst_mtc0 && ~inst_syscall && ~inst_eret && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rs != 0) && from_ms_gr_we && (from_ms_dest == rs);
assign rt_in_ms = (inst_lwl || inst_lwr || ~inst_jal && ~inst_j && ~inst_syscall && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rt != 0) && ~dst_is_rt) && from_ms_gr_we && (from_ms_dest == rt);
assign rs_in_ws = ~inst_jal && ~inst_j && ~inst_mtc0 && ~inst_syscall && ~inst_eret && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rs != 0) && from_ws_gr_we && (from_ws_dest == rs);
assign rt_in_ws = (inst_lwl || inst_lwr || ~inst_jal && ~inst_j && ~inst_syscall && ~inst_break && ~inst_tlbp && ~inst_tlbwi && ~inst_tlbr
                && (rt != 0) && ~dst_is_rt) && from_ws_gr_we && (from_ws_dest == rt);
assign rs_value = rs_in_es ? from_es_result :
                  rs_in_ms ? from_ms_result :
                  rs_in_ws ? from_ws_result :
                                 rf_rdata1;
assign rt_value = rt_in_es ? from_es_result :
                  rt_in_ms ? from_ms_result :
                  rt_in_ws ? from_ws_result :
                                 rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);
assign rs_gtz   = !(rs_ltz || rs_value == 0);
assign rs_ltz   = rs_value[31];
assign br       = (inst_beq    | inst_bne   | inst_bgtz | inst_bgez | inst_bltz | inst_blez 
                 | inst_bltzal | inst_bgezal| inst_jalr | inst_jal  | inst_jr   | inst_j) & ds_valid;
assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgtz   &&  rs_gtz
                   || inst_bgez   && !rs_ltz
                   || inst_bltz   &&  rs_ltz
                   || inst_blez   && !rs_gtz
                   || inst_bltzal &&  rs_ltz
                   || inst_bgezal && !rs_ltz
                   || inst_jalr
                   || inst_jal
                   || inst_jr
                   || inst_j
                  ) && ds_to_es_valid;
assign br_target = (inst_bgtz   || inst_bgez 
                 || inst_bltz   || inst_blez 
                 || inst_bltzal || inst_bgezal
                 || inst_beq    || inst_bne)   ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr)      ? rs_value :
                  /*inst_jal || inst_j*/         {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule

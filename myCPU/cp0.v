`include "mycpu.h"

module cp0(
    input         clk,
    input         reset,
    
    input         mtc0_we,
    input  [ 4:0] c0_addr,
    input  [31:0] c0_wdata,
    
    //status
    input         ex,
    input         eret_flush,
    output [31:0] c0_status,
    
    //cause
    input         bd,
    input         count_eq_compare,
    input  [ 5:0] ext_int_in,
    input  [ 4:0] excode,
    output [31:0] c0_cause,
    
    //epc
    input  [31:0] pc,
    output reg [31:0] c0_epc,
    
    //badvaddr
    input  [31:0] badvaddr,
    output reg [31:0] c0_badvaddr,
    
    //count
    output reg [31:0] c0_count,
    
    //compare
    output reg [31:0] c0_compare,
    
    //entryhi
    input         tlbr_op,
    input  [18:0] r_vpn2,
    input  [ 7:0] r_asid,
    output [31:0] c0_entryhi,
    
    //entrylo
    input         r_g,
    input  [19:0] r_pfn0,
    input  [ 2:0] r_c0,
    input         r_d0,
    input         r_v0, 
    input  [19:0] r_pfn1, 
    input  [ 2:0] r_c1, 
    input         r_d1, 
    input         r_v1,
    output [31:0] c0_entrylo0,
    output [31:0] c0_entrylo1,
    
    //index
    input         tlbp_op,
    input         s1_found,
    input  [ 3:0] s1_index,
    output [31:0] c0_index
);

wire        c0_status_bev;
reg  [ 7:0] c0_status_im;
reg         c0_status_exl;
reg         c0_status_ie;
assign c0_status = {9'd0         , //31:23
                    c0_status_bev, //22:22
                    6'd0         , //21:16
                    c0_status_im , //15:8
                    6'd0         , //7:2
                    c0_status_exl, //1:1
                    c0_status_ie   //0:0
                   };
                    
assign c0_status_bev = 1'b1;
always @(posedge clk) begin
    if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_im <= c0_wdata[15:8];
        
    if (reset) 
        c0_status_exl <= 1'b0;
    else if (ex) 
        c0_status_exl <= 1'b1; 
    else if (eret_flush) 
        c0_status_exl <= 1'b0; 
    else if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_exl <= c0_wdata[1];
        
    if (reset)
        c0_status_ie <= 1'b0;
    else if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_ie <= c0_wdata[0];
end

reg         c0_cause_bd;
reg         c0_cause_ti;
reg  [ 7:0] c0_cause_ip;
reg  [ 4:0] c0_cause_excode;
assign c0_cause = {c0_cause_bd    , //31:31
                   c0_cause_ti    , //30:30
                   14'd0          , //29:16
                   c0_cause_ip    , //15:8
                   1'd0           , //7:7
                   c0_cause_excode, //6:2
                   2'd0             //1:0
                  };

reg         tick;


reg  [18:0] c0_entryhi_vpn2;
reg  [ 7:0] c0_entryhi_asid;
assign c0_entryhi = {c0_entryhi_vpn2, //31:13
                     5'd0           , //12:8
                     c0_entryhi_asid  //7:0
                    };


reg  [19:0] c0_entrylo_pfn0;
reg  [ 2:0] c0_entrylo_c0;
reg         c0_entrylo_d0;
reg         c0_entrylo_v0;
reg         c0_entrylo_g0;
assign c0_entrylo0 = {6'd0           , //31:26
                      c0_entrylo_pfn0, //25:6
                      c0_entrylo_c0  , //5:3
                      c0_entrylo_d0  , //2:2
                      c0_entrylo_v0  , //1:1
                      c0_entrylo_g0    //0:0
                     };

reg  [19:0] c0_entrylo_pfn1;
reg  [ 2:0] c0_entrylo_c1;
reg         c0_entrylo_d1;
reg         c0_entrylo_v1;
reg         c0_entrylo_g1;
assign c0_entrylo1 = {6'd0           , //31:26
                      c0_entrylo_pfn1, //25:6
                      c0_entrylo_c1  , //5:3
                      c0_entrylo_d1  , //2:2
                      c0_entrylo_v1  , //1:1
                      c0_entrylo_g1    //0:0
                     };

reg         c0_index_p;
reg  [ 3:0] c0_index_index;
assign c0_index = {c0_index_p    , //31:31
                   27'd0         , //30:4
                   c0_index_index  //3:0
                  };
               
always @(posedge clk) begin
    if (reset)
        c0_cause_bd <= 1'b0;
    else if (ex && !c0_status_exl)
        c0_cause_bd <= bd;
    
    if (reset)
        c0_cause_ti <= 1'b0;
    else if (mtc0_we && c0_addr==`CR_COMPARE)
        c0_cause_ti <= 1'b0;
    else if (count_eq_compare)
        c0_cause_ti <= 1'b1;
    
    if (reset)
        c0_cause_excode <= 1'b0;
    else if (ex)
        c0_cause_excode <= excode;
end

always @(posedge clk) begin
    if (reset)
        c0_cause_ip[7:2] <= 6'b0;
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
    
    if (reset)
        c0_cause_ip[1:0] <= 2'b0;
    else if (mtc0_we && c0_addr==`CR_CAUSE)
        c0_cause_ip[1:0] <= c0_wdata[9:8];
end

always @(posedge clk) begin
    if (ex && !c0_status_exl)
        c0_epc <= bd ? pc - 3'h4 : pc;
    else if (mtc0_we && c0_addr==`CR_EPC)
        c0_epc <= c0_wdata;
end

always @(posedge clk) begin
    if (ex && (excode==`EX_ADEL||excode==`EX_ADES||excode==`EX_MOD
             ||excode==`EX_TLBL||excode==`EX_TLBS))
        c0_badvaddr <= badvaddr;
end

always @(posedge clk) begin
    if (reset) 
        tick <= 1'b0;
    else
        tick <= ~tick;
    
    if (mtc0_we && c0_addr==`CR_COUNT)
        c0_count <= c0_wdata;
    else if (tick)
        c0_count <= c0_count + 1'b1;
end

always @(posedge clk) begin
    if (mtc0_we && c0_addr==`CR_COMPARE)
        c0_compare <= c0_wdata;
end

always @(posedge clk) begin
    if (reset)
        c0_entryhi_vpn2 <= 19'b0;
    else if (ex && (excode==`EX_MOD||excode==`EX_TLBL||excode==`EX_TLBS))
        c0_entryhi_vpn2 <= badvaddr[31:13];
    else if (tlbr_op)
        c0_entryhi_vpn2 <= r_vpn2;
    else if (mtc0_we && c0_addr==`CR_ENTRYHI)
        c0_entryhi_vpn2 <= c0_wdata[31:13];
    
    if (reset)
        c0_entryhi_asid <= 8'b0;
    else if (tlbr_op)
        c0_entryhi_asid <= r_asid;
    else if (mtc0_we && c0_addr==`CR_ENTRYHI)
        c0_entryhi_asid <= c0_wdata[7:0];
end

always @(posedge clk) begin
    if (mtc0_we && c0_addr==`CR_ENTRYLO0) begin
        c0_entrylo_pfn0 <= c0_wdata[25:6];
        c0_entrylo_c0   <= c0_wdata[5:3];
        c0_entrylo_d0   <= c0_wdata[2:2];
        c0_entrylo_v0   <= c0_wdata[1:1];
        c0_entrylo_g0   <= c0_wdata[0:0];
    end
    else if (tlbr_op) begin
        c0_entrylo_pfn0 <= r_pfn0;
        c0_entrylo_c0   <= r_c0;
        c0_entrylo_d0   <= r_d0;
        c0_entrylo_v0   <= r_v0;
        c0_entrylo_g0   <= r_g;
    end
end

always @(posedge clk) begin
    if (mtc0_we && c0_addr==`CR_ENTRYLO1) begin
        c0_entrylo_pfn1 <= c0_wdata[25:6];
        c0_entrylo_c1   <= c0_wdata[5:3];
        c0_entrylo_d1   <= c0_wdata[2:2];
        c0_entrylo_v1   <= c0_wdata[1:1];
        c0_entrylo_g1   <= c0_wdata[0:0];
    end
    else if (tlbr_op) begin
        c0_entrylo_pfn1 <= r_pfn1;
        c0_entrylo_c1   <= r_c1;
        c0_entrylo_d1   <= r_d1;
        c0_entrylo_v1   <= r_v1;
        c0_entrylo_g1   <= r_g;
    end
end

always @(posedge clk) begin
    if (reset)
        c0_index_p <= 1'b0;
    else if (tlbp_op)
        c0_index_p <= ~s1_found;
        
    if (mtc0_we && c0_addr==`CR_INDEX)
        c0_index_index <= c0_wdata[3:0];
    else if (tlbp_op)
        c0_index_index <= s1_index;
end

endmodule
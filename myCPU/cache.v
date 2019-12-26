`define IDLE    3'b000
`define LOOKUP  3'b001
`define MISS    3'b010
`define REPLACE 3'b011
`define REFILL  3'b100

module cache(
    input          clk,
    input          resetn,
    // sram-like
    input          valid,
    input  [  2:0] cachable,
    input          op,
    input  [  7:0] index,
    input  [ 19:0] tlb_tag,
    input  [  3:0] offset,
    input  [  3:0] wstrb,
    input  [ 31:0] wdata,
    output         addr_ok,
    output         data_ok,
    output [ 31:0] rdata,
    // axi: read
    output         rd_req,
    output [  2:0] rd_type,
    output [ 31:0] rd_addr,
    input          rd_rdy,
    input          ret_valid,
    input          ret_last,
    input  [ 31:0] ret_data,
    // axi: write
    output         wr_req,
    output [  2:0] wr_type,
    output [ 31:0] wr_addr,
    output [  3:0] wr_wstrb,
    output [127:0] wr_data,
    input          wr_rdy
);

reg  [255:0] way0_d, way1_d;

wire [  7:0] cache_addr;
wire [ 19:0] way0_tag, way1_tag;
wire         way0_v, way1_v;
wire [127:0] way0_data, way1_data;
wire         way0_tagv_we, way1_tagv_we;
wire [  3:0] way0_wstrb0, way0_wstrb1, way0_wstrb2, way0_wstrb3;
wire [  3:0] way1_wstrb0, way1_wstrb1, way1_wstrb2, way1_wstrb3;
wire [  3:0] cache_wstrb;
wire [  1:0] cache_wbank;
wire         cache_wway;
wire [ 31:0] cache_wdata;

reg  [  4:0] pseudo_random_5;

reg  [ 2:0] state, next;

reg         op_r;
reg  [ 2:0] cachable_r;
reg  [ 7:0] index_r;
reg  [19:0] tlb_tag_r;
reg  [ 3:0] offset_r;
reg  [ 3:0] wstrb_r;
reg  [31:0] wdata_r;

reg  [ 19:0] replace_tag_r;
reg          replace_v_r;
reg  [127:0] replace_data_r;
wire         replace_d;

wire        way0_hit, way1_hit, cache_hit;
wire [31:0] way0_load_word, way1_load_word;
wire [31:0] load_res;

reg         replace_way;

wire        cached;

reg  [ 1:0] ret_cnt;

reg  [31:0] ret_buf;
reg         ret_buf_valid;

always @(posedge clk) begin
    if (!resetn)
        state <= `IDLE;
    else
        state <= next;
end

always @(*) begin
    case(state)
    `IDLE: 
        if (valid)              // 有请求: IDLE->LOOKUP
            next = `LOOKUP;
        else                    // 无请求: IDLE->IDLE
            next = state;
    `LOOKUP: 
        if (!cache_hit)         // Cache缺失: LOOKUP->MISS
            next = `MISS;
        else if (!op_r&&valid)  // 连续的读请求: LOOKUP->LOOKUP
            next = `LOOKUP;
        else                    // HitStore或者没有请求: LOOKUP->IDLE 
            next = `IDLE;
    `MISS: 
        if (!replace_d||!cached)// 被替换数据不dirty: MISS->REPLACE
            next = `REPLACE;
        else if (wr_rdy)        // AXI写请求被接收: MISS->REPLACE
            next = `REPLACE;
        else                    // dirty且AXI写请求未接收: MISS->MISS
            next = state;
    `REPLACE: 
        if (rd_rdy)             // AXI读请求被接收: REPLACE->REFILL
            next = `REFILL;
        else                    // AXI读请求未接收: REPLACE->REPLACE
            next = state;
    `REFILL:                    
        if (ret_valid&&ret_last)// AXI数据接收完毕: REFILL->IDLE
            next = `IDLE;
        else                    // AXI数据未接收完: REFILL->REFILL
            next = `REFILL;
    default: 
        next = state;
    endcase
end

// request buffer
always @(posedge clk) begin
    if (next==`LOOKUP) begin
        op_r       <= op;
        cachable_r <= cachable;
        index_r    <= index;
        tlb_tag_r  <= tlb_tag;
        offset_r   <= offset;
        wstrb_r    <= wstrb;
        wdata_r    <= wdata;
    end
end

always @(posedge clk) begin
    if (state==`REFILL && ret_valid && ret_cnt==offset_r[3:2])
        ret_buf <= ret_data;
        
    if (state==`REFILL && next==`IDLE)
        ret_buf_valid <= 1;
    else
        ret_buf_valid <= 0;
end

assign cached = (cachable_r == 3'h3);

// tag compare & data select
assign way0_hit  = way0_v && cached && (way0_tag == tlb_tag_r); 
assign way1_hit  = way1_v && cached && (way1_tag == tlb_tag_r); 
assign cache_hit = way0_hit || way1_hit;

assign way0_load_word = way0_data[offset_r[3:2]*32 +: 32]; 
assign way1_load_word = way1_data[offset_r[3:2]*32 +: 32]; 
assign load_res = {32{way0_hit}} & way0_load_word
                | {32{way1_hit}} & way1_load_word;

// replace buffer
always @(posedge clk) begin
    if (next==`LOOKUP)
        replace_way <= pseudo_random_5[0];
end

always @(posedge clk) begin
    if (next==`MISS) begin
        replace_tag_r  <= replace_way ? way1_tag : way0_tag;
        replace_v_r    <= replace_way ? way1_v : way0_v;
        replace_data_r <= replace_way ? way1_data : way0_data;
    end
end

assign replace_d = replace_way ? way1_d[index_r] : way0_d[index_r];

// ret_cnt
always @(posedge clk) begin
    if (!resetn)
        ret_cnt <= 2'b0;
    else if (!cached)
        ret_cnt <= offset_r[3:2];
    else if (next==`REPLACE) 
        ret_cnt <= 2'b0;
    else if (ret_valid)
        ret_cnt <= ret_cnt + 2'b1;
end

// output ports
assign addr_ok = (next==`LOOKUP);
assign data_ok = (state==`LOOKUP && cache_hit)
              || (state==`IDLE && ret_buf_valid);
assign rdata   = (state==`LOOKUP) ? load_res : ret_buf;

assign rd_req  = (state==`REPLACE);
assign rd_type = cached ? 3'b100 : 3'b010; 
assign rd_addr = {tlb_tag_r, index_r, cached ? 2'b0 : offset_r[3:2], 2'b0};

assign wr_req  = (state==`MISS) && replace_v_r && replace_d && cached;
assign wr_type = 3'b100;
assign wr_addr = {replace_tag_r,index_r,4'h0};
assign wr_data = replace_data_r;

// LSFR
always @ (posedge clk) begin
   if (!resetn)
       pseudo_random_5 <= 5'b10101;
   else
       pseudo_random_5 <= {pseudo_random_5[3:0], pseudo_random_5[4] ^ pseudo_random_5[1]};
end

// {dirty}
always @(posedge clk) begin
    if (!resetn) begin
        way0_d <= 256'b0;
        way1_d <= 256'b0;
    end
    else if (state==`LOOKUP&&cache_hit&&op_r) begin
        way0_d[index_r] <= way0_hit;
        way1_d[index_r] <= way1_hit;
    end
    else if (state==`REFILL&&op_r) begin
        way0_d[index_r] <= ~replace_way;
        way1_d[index_r] <=  replace_way;
    end
end

// {tag,v}ram
assign way0_tagv_we = (next==`REFILL) && cached && ~replace_way;
assign way1_tagv_we = (next==`REFILL) && cached &&  replace_way;
assign cache_addr   = (next==`LOOKUP) ? index : index_r;

tagv_ram 
way0_tagv_ram(
    .clka   ( clk             ),
    .wea    ( way0_tagv_we    ),
    .addra  ( cache_addr      ),
    .dina   ({tlb_tag_r,1'b1} ),
    .douta  ({way0_tag,way0_v})
),
way1_tagv_ram(
    .clka   ( clk             ),
    .wea    ( way1_tagv_we    ),
    .addra  ( cache_addr      ),
    .dina   ({tlb_tag_r,1'b1} ),
    .douta  ({way1_tag,way1_v})
);

// {data}ram
assign cache_wstrb = (state==`LOOKUP) && cache_hit && op_r   ? wstrb_r :
                     (state==`REFILL) && ret_valid && cached ? 4'b1111 :
                                                               4'b0000;
assign cache_wbank = (state==`LOOKUP) ? offset_r[3:2] :
                    /*state==`REFILL*/  ret_cnt;
assign cache_wway  = (state==`LOOKUP) ? way1_hit :
                    /*state==`REFILL*/  replace_way;
assign way0_wstrb0 = {4{cache_wway==1'b0&&cache_wbank==2'h0}} & cache_wstrb;
assign way0_wstrb1 = {4{cache_wway==1'b0&&cache_wbank==2'h1}} & cache_wstrb;
assign way0_wstrb2 = {4{cache_wway==1'b0&&cache_wbank==2'h2}} & cache_wstrb;
assign way0_wstrb3 = {4{cache_wway==1'b0&&cache_wbank==2'h3}} & cache_wstrb;
assign way1_wstrb0 = {4{cache_wway==1'b1&&cache_wbank==2'h0}} & cache_wstrb;
assign way1_wstrb1 = {4{cache_wway==1'b1&&cache_wbank==2'h1}} & cache_wstrb;
assign way1_wstrb2 = {4{cache_wway==1'b1&&cache_wbank==2'h2}} & cache_wstrb;
assign way1_wstrb3 = {4{cache_wway==1'b1&&cache_wbank==2'h3}} & cache_wstrb;
assign cache_wdata = (state==`LOOKUP)                    ? wdata_r :
                     (cache_wbank!=offset_r[3:2])||!op_r ? ret_data :
                            {wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24],
                             wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16],
                             wstrb_r[1] ? wdata_r[15:8 ] : ret_data[15:8 ],
                             wstrb_r[0] ? wdata_r[ 7:0 ] : ret_data[ 7:0 ]};

data_ram
way0_bank0_ram(
    .clka   (clk              ),
    .wea    (way0_wstrb0      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way0_data[ 31:0 ])
),
way0_bank1_ram(
    .clka   (clk              ),
    .wea    (way0_wstrb1      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way0_data[ 63:32])
),
way0_bank2_ram(
    .clka   (clk              ),
    .wea    (way0_wstrb2      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way0_data[ 95:64])
),
way0_bank3_ram(
    .clka   (clk              ),
    .wea    (way0_wstrb3      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way0_data[127:96])
),
way1_bank0_ram(
    .clka   (clk              ),
    .wea    (way1_wstrb0      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way1_data[ 31:0 ])
),
way1_bank1_ram(
    .clka   (clk              ),
    .wea    (way1_wstrb1      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way1_data[ 63:32])
),
way1_bank2_ram(
    .clka   (clk              ),
    .wea    (way1_wstrb2      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way1_data[ 95:64])
),
way1_bank3_ram(
    .clka   (clk              ),
    .wea    (way1_wstrb3      ),
    .addra  (cache_addr       ),
    .dina   (cache_wdata      ),
    .douta  (way1_data[127:96])
);

endmodule
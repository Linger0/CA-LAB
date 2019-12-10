module cpu_axi_interface
(
    input   clk   ,
    input   resetn,

    //inst sram-like 
    input         inst_req    ,
    input  [ 1:0] inst_size   ,
    input  [31:0] inst_addr   ,
    output [31:0] inst_rdata  ,
    output        inst_addr_ok,
    output reg    inst_data_ok,
    
    //data sram-like 
    input         data_req    ,
    input         data_wr     ,
    input  [ 1:0] data_size   ,
    input  [31:0] data_addr   ,
    input  [ 3:0] data_wstrb  ,
    input  [31:0] data_wdata  ,
    output [31:0] data_rdata  ,
    output        data_addr_ok,
    output reg    data_data_ok,

    //axi
    //ar
    output [ 3:0] arid   ,
    output [31:0] araddr ,
    output [ 7:0] arlen  ,
    output [ 2:0] arsize ,
    output [ 1:0] arburst,
    output [ 1:0] arlock ,
    output [ 3:0] arcache,
    output [ 2:0] arprot ,
    output        arvalid,
    input         arready,
    //r              
    input  [ 3:0] rid    ,
    input  [31:0] rdata  ,
    input  [ 1:0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    //aw           
    output [ 3:0] awid   ,
    output [31:0] awaddr ,
    output [ 7:0] awlen  ,
    output [ 2:0] awsize ,
    output [ 1:0] awburst,
    output [ 1:0] awlock ,
    output [ 3:0] awcache,
    output [ 2:0] awprot ,
    output reg    awvalid,
    input         awready,
    //w          
    output [ 3:0] wid    ,
    output [31:0] wdata  ,
    output [ 3:0] wstrb  ,
    output        wlast  ,
    output reg    wvalid ,
    input         wready ,
    //b              
    input  [ 3:0] bid    ,
    input  [ 1:0] bresp  ,
    input         bvalid ,
    output reg    bready 
);

reg  [31:0] rdata_r;

reg         arid_is_0;

reg         handle_inst_req;
reg  [ 1:0] inst_size_r;
reg  [31:0] inst_addr_r;
reg         wait_inst_data;

reg         handle_data_req;
reg         data_wr_r;
reg  [ 1:0] data_size_r;
reg  [31:0] data_addr_r;
reg  [ 3:0] data_wstrb_r;
reg  [31:0] data_wdata_r;
reg         wait_data_rdata;

always @(posedge clk) begin
    if (rready && rvalid)
        rdata_r <= rdata;
end 

// inst sram-like
always @(posedge clk) begin
    if (!resetn)
        handle_inst_req <= 0;
    else if (!handle_inst_req)
        handle_inst_req <= inst_req;
    else if (rid==0 && rvalid && rready)
        handle_inst_req <= 0;
    
    if (!handle_inst_req && inst_req) begin
        inst_size_r <= inst_size;
        inst_addr_r <= inst_addr;
    end
    
    if (!resetn)
        inst_data_ok <= 0;
    else if (rid==0 && rvalid && rready)
        inst_data_ok <= 1;
    else if (inst_data_ok)
        inst_data_ok <= 0;
end

// data sram-like
always @(posedge clk) begin
    if (!resetn)
        handle_data_req <= 0;
    else if (!handle_data_req)
        handle_data_req <= data_req;
    else if (rid==1 && rvalid && rready || bvalid && bready)
        handle_data_req <= 0;
    
    if (!handle_data_req && data_req) begin
        data_wr_r    <= data_wr;
        data_size_r  <= data_size;
        data_addr_r  <= data_addr;
        data_wdata_r <= data_wdata;
        data_wstrb_r <= data_wstrb;
    end
        
    if (!resetn)
        data_data_ok <= 0;
    else if (rid==1 && rvalid && rready || bvalid && bready)
        data_data_ok <= 1;
    else if (data_data_ok)
        data_data_ok <= 0;
end

// inst read
always @(posedge clk) begin
    if (!resetn)
        wait_inst_data <= 0;
    else if (arid==0 && arvalid && arready)
        wait_inst_data <= 1;
    else if (rid==0 && rvalid && rready)
        wait_inst_data <= 0;
end

// data read
always @(posedge clk) begin
    if (!resetn)
        wait_data_rdata <= 0;
    else if (arid==1 && arvalid && arready)
        wait_data_rdata <= 1;
    else if (rid==1 && rvalid && rready)
        wait_data_rdata <= 0;
end

// data write
always @(posedge clk) begin
    if (!resetn)
        awvalid <= 0;
    else if (!handle_data_req)
        awvalid <= data_req&data_wr;
    else if (awvalid && awready)
        awvalid <= 0;
        
    if (!resetn)
        wvalid <= 0;
    else if (!handle_data_req)
        wvalid <= data_req&data_wr;
    else if (wvalid && wready)
        wvalid <= 0;
    
    if (!resetn)
        bready <= 0;
    else if (wvalid && wready)
        bready <= 1;
    else if (bvalid && bready)
        bready <= 0;
end

always @(posedge clk) begin
    if (!resetn) begin
        arid_is_0 <= 0;
    end
    else if (arid==0&&arvalid&&arready) begin
        arid_is_0 <= 0;
    end
    else if (arvalid&&arid==0) begin
        arid_is_0 <= 1;
    end
end

// ar
assign arid         = ~arid_is_0&&handle_data_req&&!data_wr_r&&!wait_data_rdata ? 1 : 0;    // 取数置为1
assign araddr       = arid==1 ? data_addr_r : inst_addr_r;
assign arsize       = arid==1 ? {1'b0, data_size_r} : {1'b0, inst_size_r};
assign arvalid      = handle_data_req&&!data_wr_r&&!wait_data_rdata 
                   || handle_inst_req&&!wait_inst_data;
// r
assign rready       = wait_inst_data || wait_data_rdata;
// aw
assign awaddr       = data_addr_r;
assign awsize       = {1'b0, data_size_r};
// w
assign wdata        = data_wdata_r;
assign wstrb        = data_wstrb_r;

// sram-like
assign inst_addr_ok = !handle_inst_req && inst_req;
assign inst_rdata   = rdata_r;
assign data_addr_ok = !handle_data_req && data_req;
assign data_rdata   = rdata_r;

// 固定信号
assign arlen    = 0;
assign arburst  = 2'b01;
assign arlock   = 0;
assign arcache  = 0;
assign arprot   = 0;
assign awid     = 1;
assign awlen    = 0;
assign awburst  = 2'b01;
assign awlock   = 0;
assign awcache  = 0;
assign awprot   = 0;
assign wid      = 1;
assign wlast    = 1;

endmodule
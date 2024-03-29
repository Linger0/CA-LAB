module mycpu_top(
    input         int,   //high active

    input         aclk,
    input         aresetn,   //low active

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
    output        awvalid,
    input         awready,
    //w          
    output [ 3:0] wid    ,
    output [31:0] wdata  ,
    output [ 3:0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    //b              
    input  [ 3:0] bid    ,
    input  [ 1:0] bresp  ,
    input         bvalid ,
    output        bready,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus;
wire [`WS_TO_DS_BUS_WD -1:0] ws_to_ds_bus;
wire [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus;

wire [`ES_TO_TLB_BUS_WD -1:0] es_to_tlb_bus;
wire [`TLB_TO_ES_BUS_WD -1:0] tlb_to_es_bus;
wire [`FS_TO_TLB_BUS_WD -1:0] fs_to_tlb_bus;
wire [`TLB_TO_FS_BUS_WD -1:0] tlb_to_fs_bus;

wire        ms_to_es_ex;
wire        ms_to_es_mtc0;
wire        ws_to_es_mtc0;

//inst sram-like 
wire        inst_req    ;
wire        inst_wr     ;
wire [ 2:0] inst_cache  ;
wire [ 1:0] inst_size   ;
wire [31:0] inst_addr   ;
wire [ 3:0] inst_wstrb  ;
wire [31:0] inst_rdata  ;
wire        inst_addr_ok;
wire        inst_data_ok;
//data sram-like 
wire        data_req    ;
wire        data_wr     ;
wire [ 1:0] data_size   ;
wire [31:0] data_addr   ;
wire [ 3:0] data_wstrb  ;
wire [31:0] data_wdata  ;
wire [31:0] data_rdata  ;
wire        data_addr_ok;
wire        data_data_ok;

wire        flush;
wire        has_int;

wire [ 2:0] inst_len;
wire [ 7:0] i_index;
wire [19:0] i_tag;
wire [ 3:0] i_offset;
wire        rd_req;
wire [ 2:0] rd_type;
wire [31:0] rd_addr;
wire        rd_rdy;
wire [31:0] ret_data;
wire        ret_valid;
wire        ret_last;

assign inst_cache = (inst_addr[31:29]==3'h4) ? 3'h3 : 3'h2;

assign inst_wr    = 1'b0;
assign inst_wstrb = 4'h0;
assign inst_len = (rd_type == 3'b100) ? 3'b011 : 3'b000;
assign {i_tag,i_index,i_offset} = inst_addr;

// IF stage
if_stage if_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //exception
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    //tlb
    .fs_to_tlb_bus  (fs_to_tlb_bus  ),
    .tlb_to_fs_bus  (tlb_to_fs_bus  ),
    // inst sram-like
    .inst_req       (inst_req       ),
    .inst_size      (inst_size      ),
    .inst_addr      (inst_addr      ),
    .inst_rdata     (inst_rdata     ),
    .inst_addr_ok   (inst_addr_ok   ),
    .inst_data_ok   (inst_data_ok   )
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //for forwarding
    .es_to_ds_bus   (es_to_ds_bus   ),
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    //exception
    .ds_flush       (flush          ),
    .ds_has_int     (has_int        )
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ds
    .es_to_ds_bus   (es_to_ds_bus   ),
    //exception
    .es_flush       (flush          ),
    .ms_to_es_ex    (ms_to_es_ex    ),
    //block tlbp
    .ms_to_es_mtc0  (ms_to_es_mtc0  ),
    .ws_to_es_mtc0  (ws_to_es_mtc0  ),
    //tlb
    .es_to_tlb_bus  (es_to_tlb_bus  ),
    .tlb_to_es_bus  (tlb_to_es_bus  ),
    // data sram interface
    .data_req       (data_req       ),
    .data_wr        (data_wr        ),
    .data_size      (data_size      ),
    .data_addr      (data_addr      ),
    .data_wstrb     (data_wstrb     ),
    .data_wdata     (data_wdata     ),
    .data_addr_ok   (data_addr_ok   )
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to ds
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //exception
    .ms_flush       (flush          ),
    .ms_to_es_ex    (ms_to_es_ex    ),
    //block tlbp
    .ms_to_es_mtc0  (ms_to_es_mtc0  ),
    //from data-sram
    .data_rdata     (data_rdata     ),
    .data_data_ok   (data_data_ok   )
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to ds
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    //exception
    .ws_flush       (flush          ),
    .has_int        (has_int        ),
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    //block tlbp
    .ws_to_es_mtc0  (ws_to_es_mtc0  ),
    //tlb
    .es_to_tlb_bus  (es_to_tlb_bus  ),
    .tlb_to_es_bus  (tlb_to_es_bus  ),
    .fs_to_tlb_bus  (fs_to_tlb_bus  ),
    .tlb_to_fs_bus  (tlb_to_fs_bus  ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

//sram-like to axi bridge
cpu_axi_interface u_axi_ifc(
    .clk           (aclk         ),
    .resetn        (aresetn      ),
    //inst sram-like 
    .inst_req      (rd_req       ),
    .inst_size     (inst_size    ),
    .inst_len      (inst_len     ),
    .inst_addr     (rd_addr      ),
    .inst_rdata    (ret_data     ),
    .inst_addr_ok  (rd_rdy       ),
    .inst_data_ok  (ret_valid    ),
    .inst_last     (ret_last     ),
    //data sram-like 
    .data_req      (data_req     ),
    .data_wr       (data_wr      ),
    .data_size     (data_size    ),
    .data_addr     (data_addr    ),
    .data_wstrb    (data_wstrb   ),
    .data_wdata    (data_wdata   ),
    .data_rdata    (data_rdata   ),
    .data_addr_ok  (data_addr_ok ),
    .data_data_ok  (data_data_ok ),
    //axi
    //ar
    .arid      (arid         ),
    .araddr    (araddr       ),
    .arlen     (arlen        ),
    .arsize    (arsize       ),
    .arburst   (arburst      ),
    .arlock    (arlock       ),
    .arcache   (arcache      ),
    .arprot    (arprot       ),
    .arvalid   (arvalid      ),
    .arready   (arready      ),
    //r              
    .rid       (rid          ),
    .rdata     (rdata        ),
    .rresp     (rresp        ),
    .rlast     (rlast        ),
    .rvalid    (rvalid       ),
    .rready    (rready       ),
    //aw           
    .awid      (awid         ),
    .awaddr    (awaddr       ),
    .awlen     (awlen        ),
    .awsize    (awsize       ),
    .awburst   (awburst      ),
    .awlock    (awlock       ),
    .awcache   (awcache      ),
    .awprot    (awprot       ),
    .awvalid   (awvalid      ),
    .awready   (awready      ),
    //w          
    .wid       (wid          ),
    .wdata     (wdata        ),
    .wstrb     (wstrb        ),
    .wlast     (wlast        ),
    .wvalid    (wvalid       ),
    .wready    (wready       ),
    //b              
    .bid       (bid          ),
    .bresp     (bresp        ),
    .bvalid    (bvalid       ),
    .bready    (bready       )
);

// cache
// I-cache
cache i_cache(
    .clk       (aclk        ),
    .resetn    (aresetn     ),
    // sram-like
    .valid     (inst_req    ),
    .cachable  (inst_cache  ),
    .op        (inst_wr     ),
    .index     (i_index     ),
    .tlb_tag   (i_tag       ),
    .offset    (i_offset    ),
    .wstrb     (inst_wstrb  ),
 // .wdata
    .addr_ok   (inst_addr_ok),
    .data_ok   (inst_data_ok),
    .rdata     (inst_rdata  ),
    // axi: read
    .rd_req    (rd_req      ),
    .rd_type   (rd_type     ),
    .rd_addr   (rd_addr     ),
    .rd_rdy    (rd_rdy      ),
    .ret_valid (ret_valid   ),
    .ret_last  (ret_last    ),
    .ret_data  (ret_data    )
);

endmodule

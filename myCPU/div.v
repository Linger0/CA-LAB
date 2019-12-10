module div(
    input         div_clk,
    input  [31:0] div_dividend_tdata,
    input  [31:0] div_divisor_tdata,
    input         div_signed,
    
    input         div_dividend_tvalid,
    output        div_dividend_tready,
    
    input         div_divisor_tvalid,
    output        div_divisor_tready,

    output        div_dout_tvalid,
    output [63:0] div_dout_tdata
);

wire        signed_dividend_tvalid, unsigned_dividend_tvalid;
wire        signed_divisor_tvalid, unsigned_divisor_tvalid  ;
wire        signed_dividend_tready, unsigned_dividend_tready;
wire        signed_divisor_tready, unsigned_divisor_tready  ;
wire        signed_dout_tvalid, unsigned_dout_tvalid        ;
wire [63:0] signed_dout_tdata, unsigned_dout_tdata          ;

assign signed_dividend_tvalid = div_dividend_tvalid & div_signed;
assign unsigned_dividend_tvalid = div_dividend_tvalid & ~div_signed;
assign signed_divisor_tvalid = div_divisor_tvalid & div_signed;
assign unsigned_divisor_tvalid = div_divisor_tvalid & ~div_signed;
assign div_dividend_tready = div_signed ? signed_dividend_tready : unsigned_dividend_tready;
assign div_divisor_tready = div_signed ? signed_divisor_tready : unsigned_divisor_tready;
assign div_dout_tvalid = div_signed ? signed_dout_tvalid : unsigned_dout_tvalid;
assign div_dout_tdata = div_signed ? signed_dout_tdata : unsigned_dout_tdata;

div_signed u_div_signed(
    .aclk(div_clk),
    .s_axis_dividend_tdata(div_dividend_tdata),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .s_axis_divisor_tdata(div_divisor_tdata),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .m_axis_dout_tdata(signed_dout_tdata),
    .m_axis_dout_tvalid(signed_dout_tvalid)
    );

div_unsigned u_div_unsigned(
    .aclk(div_clk),
    .s_axis_dividend_tdata(div_dividend_tdata),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .s_axis_divisor_tdata(div_divisor_tdata),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .m_axis_dout_tdata(unsigned_dout_tdata),
    .m_axis_dout_tvalid(unsigned_dout_tvalid)
    );

endmodule

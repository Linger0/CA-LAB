module mul(
    input  [31:0] mul_x,
    input  [31:0] mul_y,
    input         mul_signed,
    output [63:0] mul_prod
);

wire [63:0] unsigned_prod;
wire [63:0] signed_prod;

assign unsigned_prod = mul_x * mul_y;
assign signed_prod = $signed(mul_x) * $signed(mul_y);

assign mul_prod = mul_signed ? signed_prod : unsigned_prod;
    
endmodule

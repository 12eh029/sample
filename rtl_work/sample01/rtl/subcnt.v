module subcnt (
  clk,
  rst
);


input clk;
input rst;

always @clk begin
   $display("clk = %b : %5t",clk,$stime);
end


endmodule

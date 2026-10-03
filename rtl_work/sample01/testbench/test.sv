`timescale 1ns/1ns

module test;

reg clk;
reg rst;



initial begin
   $display("Simulation Start!!");
   rst = 0;
   clk = 0;
   #100;
   rst = 1;
   #1000;
   $display("Simulation End!! : %t ns",$stime);   
   $finish;
end


parameter CLK_PERIOD = 10;

always #(CLK_PERIOD/2)  clk <= !clk;

subcnt i_subcnt (
  .clk (clk),
  .rst (rst)
);

endmodule

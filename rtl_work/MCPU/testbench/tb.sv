`timescale 1ns/1ns

module tb;

reg r_clk;
reg r_rstn;


initial begin
   $display("[INFO]Simulation Start!!");
   r_rstn  = 0;
   r_clk   = 0;
   #100;
   r_rstn  = 1;
   #1000;
   $display("[INFO]Simulation End!! : %t ns",$stime);   
   $stop;
end


parameter CLK_PERIOD = 10;

always #(CLK_PERIOD/2)  r_clk <= !r_clk;

CPU i_CPU (
  .CLK             (r_clk   ),
  .RSTn            (r_rstn  )
);

endmodule

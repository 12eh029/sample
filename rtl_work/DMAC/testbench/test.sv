`timescale 1ns/1ns

module test;

reg clk;
reg rstn;
reg start;


initial begin
   $display("Simulation Start!!");
   rstn  = 0;
   start = 0;
   clk   = 0;
   #100;
   rstn  = 1;
   #100;
   start = 1;
   #10;
   #100000;
   start = 0;
   $display("Simulation End!! : %t ns",$stime);   
   //$finish;
   $stop;
end


parameter CLK_PERIOD = 10;

always #(CLK_PERIOD/2)  clk <= !clk;

EFDEC EFDEC (
 .HRESETN     (rstn),
 .HCLK        (clk),
 .HADDR       (),
 .HTRANS      (),
 .HWRITE      (),
 .HSIZE       (),
 .HBURST      (),
 .HWDATA      (),
 .HRDATA      (32'h0),
 .HREADY      (1'b1),
 .HRESP       (2'b0)
);


endmodule

`timescale 1ns/1ns

module test;

reg clk;
reg srst;
reg asrst;


initial begin
   $display("Simulation Start!!");
   asrst = 0;;
   srst  = 0;
   clk   = 0;
   #100;
   srst = 1;
   #1000;
   $display("Simulation End!! : %t ns",$stime);   
   $stop;
end


parameter CLK_PERIOD = 10;

always #(CLK_PERIOD/2)  clk <= !clk;

rgb2hsv i_rgb2hsv (
  //receive port
  .pixel_r_in      (),
  .pixel_g_in      (),
  .pixel_b_in      (),
  .first_in        (),
  .last_in         (),
  
  .receive_ack_out (),
  .receive_req_in  (),
  
  //send port
  .pixel_h_out     (),
  .pixel_s_out     (),
  .pixel_v_out     (),
  .first_out       (),
  .last_out        (),
  
  .send_ack_out    (),
  .send_req_in     (),
  
  //clk,reset
  .clk             (clk   ),
  .rst_sync        (srst  ),
  .rst_async_n     (asrst )
);

endmodule

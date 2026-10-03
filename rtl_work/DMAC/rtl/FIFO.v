module FIFO #(
   parameter P_DATA_WIDTH = 6'd32,
   parameter P_ADD_WIDTH  = 3
) (
   input                      rst_n,
   input                      hclk,
   input  [P_DATA_WIDTH-1:0]  i_data,
   input  [P_DATA_WIDTH-1:0]  o_data,
   input                      i_wen,
   input                      i_ren,
   output                     o_empty,
   output                     o_full,
   output [P_ADD_WIDTH-1:0]   o_entry,
   input                      rg_clr
);


  parameter P_DATA_DEPTH = 2**P_ADD_WIDTH;
  
  wire [P_ADD_WIDTH-1:0] w_wptr1;
  wire [P_ADD_WIDTH-1:0] w_rptr1;


  reg  [P_ADD_WIDTH-1:0]  r_wptr;
  reg  [P_ADD_WIDTH-1:0]  r_rptr;
  reg  [P_DATA_WIDTH-1:0] fifo_data[0:P_DATA_DEPTH];
  
  reg                     r_empty;
  reg                     r_full;
  
  // Pointer
  assign w_wptr1 = r_wptr + 1;
  assign w_rptr1 = r_rptr + 1;

  //fifo
  for (genvar i =0; i< P_DATA_DEPTH; i++) begin : fifodata
     always @(posedge hclk or negedge rst_n)
        if(~rst_n)
           fifo_data[i] <= {P_DATA_DEPTH{1'b0}};
        else if ( (i_wen && ~r_full) && (i == r_wptr))
           fifo_data[i] <= i_data;
  end
  
  
  // W pointer
  always @(posedge hclk or negedge rst_n)
     if(~rst_n)
         r_wptr <=    {P_ADD_WIDTH{1'b0}};
     else if (rg_clr)
         r_wptr <=    {P_ADD_WIDTH{1'b0}};
     else if ((i_wen && ~r_full))
         r_wptr <=    w_wptr1;

  // R pointer
  always @(posedge hclk or negedge rst_n)
     if(~rst_n)
         r_rptr <=    {P_ADD_WIDTH{1'b0}};
     else if (rg_clr)
         r_rptr <=    {P_ADD_WIDTH{1'b0}};
     else if ((i_ren && ~r_empty))
         r_rptr <=    w_rptr1;
  
  // W empty
  always @(posedge hclk or negedge rst_n)
     if(~rst_n)
         r_empty <=    {P_ADD_WIDTH{1'b0}};
     else if (rg_clr)
         r_empty <=    {P_ADD_WIDTH{1'b0}};
     else if ((w_rptr1 == r_wptr && ~i_wen && i_ren))
         r_empty <=    1'b1;
     else if (r_empty && i_wen)
         r_empty <=    1'b0;
         
  //Full
  always @(posedge hclk or negedge rst_n)
     if(~rst_n)
         r_full <=    {P_ADD_WIDTH{1'b0}};
     else if (rg_clr)
         r_full <=    {P_ADD_WIDTH{1'b0}};
     else if ((w_wptr1 == r_rptr && ~i_ren && i_wen))
         r_full <=    1'b1;
     else if (r_full && i_ren)
         r_full <=    1'b0;


  assign o_empty = r_empty;
  assign o_full  = r_full;
  assign o_data  = fifo_data[r_rptr];
  assign o_entry = r_wptr - r_rptr;

endmodule
module rgb2hsv (
  //receive port
  pixel_r_in,
  pixel_g_in,
  pixel_b_in,
  first_in,
  last_in,
  
  receive_ack_out,
  receive_req_in,

  //send port
  pixel_h_out,
  pixel_s_out,
  pixel_v_out,
  first_out,
  last_out,

  send_ack_out,
  send_req_in,

  //clk,reset
  clk,
  rst_sync,
  rst_async_n
);

//receive port
input   [7:0] pixel_r_in;
input   [7:0] pixel_g_in;
input   [7:0] pixel_b_in;
input         first_in;
input         last_in;

output        receive_ack_out;
input         receive_req_in;

//send port
output  [7:0] pixel_h_out;
output  [7:0] pixel_s_out;
output  [7:0] pixel_v_out;
output        first_out;
output        last_out;

output        send_ack_out;
output        send_req_in;

//clk,reset
input         clk;
input         rst_sync;
input         rst_async_n;

initial  begin
   $display("rgb2hsv start: %5t",$stime);
end

//dataflow control

wire rwreq_pi;
wire rwreq_sft;
wire send_last;

parameter ST_WAIT_REQ     = 2'b00;
parameter ST_ISSUE_RDACK  = 2'b01;
parameter ST_WAIT_LAST    = 2'b10;

reg [1:0] state_reg;

always @(posedge clk or negedge rst_async_n) begin
   if (!rst_async_n) begin
      state_reg <= ST_WAIT_REQ;
   end
   else begin
      if (rst_sync) begin
         state_reg <= ST_WAIT_REQ;
      end
      else begin
         case (state_reg)
         ST_WAIT_REQ    : begin
             if(rwreq_pi && rwreq_sft) begin
                state_reg <= ST_ISSUE_RDACK;
             end
         end
         ST_ISSUE_RDACK : begin
            state_reg <= ST_WAIT_LAST;
         end
         ST_WAIT_LAST   : begin
            if (send_last) begin
               state_reg <= ST_WAIT_REQ;
            end
         end
         default        : begin
            state_reg <= ST_WAIT_REQ;
         end
         endcase
      end
   end
end


//--------------------
//stage0
//--------------------
reg [7:0] s0_r_reg;
reg [7:0] s0_g_reg;
reg [7:0] s0_b_reg;
reg       s0_first_reg;
reg       s0_last_reg;
reg       s0_rwreq_reg;
reg       s0_rdack_reg;


always @(posedge clk or negedge rst_async_n) begin
   if(!rst_async_n)begin
      s0_r_reg     <= 8'h00;
      s0_g_reg     <= 8'h00;
      s0_b_reg     <= 8'h00;
      s0_first_reg <= 1'b0;
      s0_last_reg  <= 1'b0;
   end
   else begin
      s0_r_reg     <= pixel_r_in;
      s0_g_reg     <= pixel_g_in;
      s0_b_reg     <= pixel_b_in;
      s0_first_reg <= first_in;
      s0_last_reg  <= last_in;
   end
end

always @(posedge clk or negedge rst_async_n) begin
   if(!rst_async_n)begin
      s0_rwreq_reg <= 1'b0;
      s0_rdack_reg <= 1'b0;
   end
   else begin
      if(rst_sync)begin
         s0_rwreq_reg <= 1'b0;
      end
      else if (receive_req_in && send_req_in) begin
         s0_rwreq_reg <= 1'b1;
      end
      else begin
         s0_rwreq_reg <= 1'b0;
      end

      if(rst_sync)begin
         s0_rdack_reg <= 1'b0;
      end
      else if (state_reg == ST_ISSUE_RDACK) begin
         s0_rdack_reg <= 1'b1;
      end
      else begin
         s0_rdack_reg <= 1'b0;
      end
   end
end



//--------------
// stage1
//--------------
wire  [7:0] s1_max;
wire  [7:0] s1_min;
wire  [8:0] s1_tmp0;
wire  [8:0] s1_tmp1;
wire  [7:0] s1_tmp2;
wire [13:0] s1_tmp3;
wire [13:0] s1_tmp4;
wire [14:0] s1_dividend_h;
wire  [7:0] s1_divisor_h;
wire [15:0] s1_dividend_s;

wire        s1_r_max;
wire        s1_g_max;

reg   [7:0] s1_max_reg;
reg   [7:0] s1_min_reg;
reg  [14:0] s1_dividend_h_reg;
reg   [7:0] s1_divisor_h_reg;
reg  [15:0] s1_dividend_s_reg;
reg         s1_r_max_reg;
reg         s1_g_max_reg;
reg         s1_first_reg;
reg         s1_last_reg;
reg         s1_rwreq_reg;
reg         s1_rdack_reg;

//compute max/min
assign s1_max = (s0_r_reg > s0_g_reg && s0_r_reg > s0_b_reg) ? s0_r_reg :
                (s0_g_reg > s0_b_reg ) ? s0_g_reg : s0_b_reg;

assign s1_min = (s0_r_reg < s0_g_reg && s0_r_reg < s0_b_reg) ? s0_r_reg :
                (s0_g_reg < s0_b_reg ) ? s0_g_reg : s0_b_reg;

//check max
assign s1_r_max = (s1_max == s0_r_reg) ? 1'b1 : 1'b0;
assign s1_g_max = (s1_max == s0_g_reg) ? 1'b1 : 1'b0;

assign s1_tmp0  = s1_r_max ? ({1'b0,s0_g_reg} - {1'b0, s0_b_reg}) :
                  s1_g_max ? ({1'b0,s0_b_reg} - {1'b0, s0_r_reg}) :
                             ({1'b0,s0_r_reg} - {1'b0, s0_g_reg}) ;



//signed mult
assign s1_tmp1 = (~s1_tmp0) + 1'b1;
assign s1_tmp2 = ~s1_tmp0[8] ?  s1_tmp0[7:0] : s1_tmp1[7:0];
assign s1_tmp3 = s1_tmp2 * 6'd60;

assign s1_tmp4       = ~s1_tmp3 + 1'b1;
assign s1_dividend_h = ~s1_tmp0[8] ? {1'b0,s1_tmp3} : {1'b1,s1_tmp4};

assign s1_divisor_h  = s1_max - s1_min;


assign s1_dividend_s = s1_divisor_h * 8'h256;

always @(clk) begin
   s1_max_reg        <= s1_max;
   s1_min_reg        <= s1_min;
   s1_divisor_h_reg  <= s1_divisor_h;
   s1_dividend_h_reg <= s1_dividend_h;
   s1_dividend_s_reg <= s1_dividend_s;
   s1_first_reg      <= s0_first_reg;
   s1_last_reg       <= s0_last_reg;
   s1_r_max_reg      <= s1_r_max;
   s1_g_max_reg      <= s1_g_max;
end

always @(posedge clk or negedge rst_async_n) begin
   if(!rst_async_n)begin
      s1_rwreq_reg <= 1'b0;
      s1_rdack_reg <= 1'b0;
   end
   else begin
      if(rst_sync)begin
         s1_rwreq_reg <= 1'b0;
         s1_rdack_reg <= 1'b0;
      end
      else begin
         s1_rwreq_reg <= s1_rwreq_reg;
         s1_rdack_reg <= s1_rdack_reg;
      end
   end
end

// stage2(div)
wire s2 qu


endmodule

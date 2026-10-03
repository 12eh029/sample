module DMYRD (
  input          HRESETN,
  input          HCLK,
  output  [31:0] HADDR,
  output  [ 1:0] HTRANS,
  output         HWRITE,
  output  [ 2:0] HSIZE,
  output  [ 3:0] HBURST,
  output  [31:0] HWDATA,
  input   [31:0] HRDATA,
  input          HREADY,
  input   [ 1:0] HRESP,

  input          ISYNC,
  output         OSYNC,
  input   [16:0] IADR_SIZE,
  input          ISTART,
  input          ISYNC_OFF,
  output  [31:0] OMON_CNT0,
  output  [31:0] OMON_CNT1,
  output  [31:0] HRDAYA_hold 
);



initial begin
   $display("DMYRD START!!");
end

parameter P_BASE_ADDR = 16'h0030;


typedef enum logic [3:0] { INIT          = 4'h1,
                           TRANS         = 4'h2,
                           TRANS_LAST_NS = 4'h4,
                           TRANS_LAST_S  = 4'h8  } state_t;


state_t state,nxt_state;

logic        w_sync;
logic        last_adr_flag;
logic        last_adr_nosync;
logic        last_adr_sync;
logic [13:0] nxt_haddr;
logic        nxt_htrans;
logic [13:0] haddr_15_2;
logic        htrans1;
logic [31:0] htrans_cnt;
logic [31:0] haddrwrap_cnt;
logic        start_pos;
logic        start_1d;
logic        hready_trans1;
logic        hready_trans1_last;
logic [31:0] hrdata_latch;


//logic
assign last_adr_flag   = ({1'b0, haddr_15_2} == 15'(IADR_SIZE[16:2] ^ 15'd1));
assign w_sync          = ISYNC || ISYNC_OFF;
assign last_adr_nosync = last_adr_flag && ~w_sync;
assign last_adr_sync   = last_adr_flag && w_sync;
assign hready_htrans1  = HREADY & HTRANS[1];
assign hready_htrans1_last = hready_htrans1 & last_adr_flag;


always @(posedge HCLK or negedge HRESETN) begin
   if(~HRESETN)begin
      start_1d <= 1'b0;
   end
   else begin
     start_1d <= ISTART;
   end
end

assign start_pos = ISTART & ~start_1d;

always @(*) begin
   case (state)
      INIT          : begin
         if (ISTART)  nxt_state = TRANS;
      end
      TRANS         : begin
                      if (~ISTART) begin
                          nxt_state = INIT;
                       end
                       else if (last_adr_nosync) nxt_state = TRANS_LAST_NS;
                       else                      nxt_state = TRANS_LAST_S;
      end
      TRANS_LAST_NS : begin
                      if (~ISTART) begin
                          nxt_state = INIT;
                       end
                       else if (w_sync) nxt_state = TRANS;
                       else             nxt_state = TRANS_LAST_NS;
      end
      TRANS_LAST_S  : begin
                      if (~ISTART)      nxt_state = INIT;
                      else              nxt_state = TRANS_LAST_NS;
      end
      default       : nxt_state = INIT;
   endcase 
end


always @(posedge HCLK or negedge HRESETN) begin
   if(~HRESETN)begin
      state <= INIT;
   end
   else begin
     state <= nxt_state;
   end
end


always @(*) begin
   case (state)
      INIT          : nxt_haddr = 14'h0;
      TRANS         : begin
          if(last_adr_flag) nxt_haddr = 14'h0;
          else              nxt_haddr = 14'(haddr_15_2 + 14'd1);
      end
      TRANS_LAST_NS : nxt_haddr = 14'h0;
      TRANS_LAST_S  : nxt_haddr = 14'(haddr_15_2 + 14'd1);
      default       : nxt_haddr = 14'h0;
   endcase 
end


always @(posedge HCLK or negedge HRESETN) begin
   if(~HRESETN)begin
      haddr_15_2 <= 14'h0;
   end
   else begin
     haddr_15_2 <= nxt_haddr;
   end
end


always @(*) begin
   case (state)
      INIT          : nxt_htrans = 1'b0;
      TRANS         : nxt_htrans = 1'b1; 
      TRANS_LAST_NS : nxt_htrans = 1'b0;
      TRANS_LAST_S  : nxt_htrans = 1'b1;
      default       : nxt_htrans = 1'b0;
   endcase 
end

always @(posedge HCLK or negedge HRESETN) begin
   if(~HRESETN)begin
      htrans1 <= 1'b1;
   end
   else begin
     htrans1 <= nxt_htrans;
   end
end

//SSS



endmodule

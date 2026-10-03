module EFD_AHB_M_R (
   input         hresetn,
   input         hclk,
   output        o_hsel,
   output [31:0] o_haddr,
   output        o_hwrite,
   output [ 2:0] o_hsize,
   output [ 2:0] o_hburst,
   output [ 1:0] o_htrans,
   input         i_hready,
   input         i_hresp,
   input  [31:0] i_hrdata,
   input         rg_start,
   input         rg_restart,
   input         rg_suspend,
   input  [31:0] rg_fix_add_s,
   input  [31:0] rg_fix_add_e,
   input  [31:0] rg_var_add_s,
   input  [31:0] rg_var_add_e,  
   input  [31:0] rg_rsv_fix_add_s,
   input  [31:0] rg_rsv_fix_add_e,
   input  [31:0] rg_rsv_var_add_s,
   input  [31:0] rg_rsv_var_add_e,
   input  [ 1:0] rg_efmode,
   output        o_read_comp,
   output [31:0] o_fix_data,
   output        o_fix_write_en,
   output [31:0] o_var_data,
   output        o_var_write_en,
   input         i_fix_full,
   input         i_var_full,
   output        o_bus_err,
   output        o_busy,
   output        o_fix_suspend,
   output        o_var_suspend,
   input         i_fault_cnt_end_flg,
   output        o_fix_comp,
   output        o_var_comp,
   input         rg_clr
);  

   //====================================================
   // parameter
   //====================================================
   parameter P_dly = 'd1;
   parameter P_R_IDLE   = 3'b000;
   parameter P_R_INTVAL = 3'b001;
   parameter P_R_F_AREA = 3'b010;
   parameter P_R_V_AREA = 3'b011;
   parameter P_R_CLR    = 3'b100;


   //=====================================================
   // wire
   //=====================================================
   wire  w_rem_dec;
   wire  w_fix_add_inc;
   wire  w_var_add_inc;
   wire  w_fix_add_skip;
   wire  w_var_add_skip;
   wire  w_fix_add_update;
   wire  w_var_add_update;
   wire  w_datain_fix;
   wire  w_datafin_var;
   wire  w_start;
   wire  w_end;
   
   wire  [31:0] w_fix_add;
   wire  [31:0] w_var_add;
   
   wire         w_rem_set;
   wire  [31:0] w_rg_add_s;
   wire  [31:0] w_rg_add_e;
   
   wire  [ 2:0] w_rcnt;
   wire  [ 2:0] w_set;
   wire         w_fix_suspend;
   wire         w_var_suspend;
   wire         w_fix_last;
   wire         w_var_last;
   
   wire  [31:0] w_fix_add_e_last;
   wire  [31:0] w_var_add_e_last;

   wire         w_clr;
   wire         w_last;
   
   wire          w_mode_normal;
   wire          w_mode_read;
   wire          w_mode_skip;
   wire          w_start_mask;
   wire          w_var_full_mask;
   wire          w_var_suspend_mask;
   wire          w_var_compleate_mask;

   //=====================================================
   // reg
   //=====================================================

   reg   [2:0]   next_state;
   reg   [2:0]   current_state;
   reg  [31:0]   r_add_out;
   reg           r_htrans;
   reg           r_busy;
   reg           r_sel;
   reg           r_bus_err;
   reg           r_last_read;
   reg   [2:0]   r_rcnt;
   reg           r_fix_suspend;
   reg           r_var_suspend;
   reg           r_fix_suspend_dly;
   reg           r_var_suspend_dly;

   reg   [1:0]   r_fix_last;
   reg   [1:0]   r_var_last;
   reg           r_clr;
   reg           r_fix_compleate;
   reg           r_var_compleate;
   
   reg           r_read_compleate;

 
   //====================================================
   assign w_mode_noraml = (rg_efmode == 2'b00);
   assign w_mode_read   = (rg_efmode == 2'b01);
   assign w_mode_dmac   = (rg_efmode == 2'b10);
   assign w_mode_skip   = (rg_efmode == 2'b11);

   assign w_start_mask  = (w_mode_normal) && rg_start;
   
   assign w_var_full_mask       = (w_mode_normal) ? i_var_full      : 1'b1;
   assign w_var_suspend_mask    = (w_mode_normal) ? r_var_suspend   : 1'b1;
   assign w_var_compleate_mask  = (w_mode_normal) ? r_var_compleate : 1'b1;

   //Main State
   always @(posedge hclk or negedge hresetn)
      if (~hresetn)
         current_state <= #P_dly P_R_IDLE;
      else if (r_clr)
         current_state <= #P_dly P_R_IDLE;
      else
         current_state <= #P_dly  next_state;
         
   
   always @(*)
      case (current_state )
      P_R_IDLE :
         if(rg_clr)
             next_state = P_R_CLR;
          else if( w_start_mask)
             next_state = P_R_INTVAL;
          else
             next_state = P_R_IDLE;
      P_R_INTVAL :
         if(rg_clr)
             next_state = P_R_CLR;
          else if ((r_fix_compleate && w_var_compleate_mask) || i_fault_cnt_end_flg )
             next_state  = P_R_IDLE;
          else if (i_fix_full && w_var_full_mask)
             next_state  = P_R_INTVAL;
          else if (r_fix_suspend | w_var_suspend_mask)
             next_state  = P_R_INTVAL;
          else if (w_var_full_mask && r_fix_compleate)
             next_state  = P_R_INTVAL;
          else if (i_fix_full && w_var_compleate_mask)
             next_state  = P_R_INTVAL;
          else if (~i_fix_full & r_fix_last[1])
             next_state  = P_R_F_AREA;
          else if (~w_var_full_mask & r_var_last[1])
             next_state  = P_R_V_AREA;
          else if (w_var_full_mask)
             next_state  = P_R_F_AREA;
          else if (i_fix_full && w_mode_normal)
             next_state  = P_R_V_AREA;
          else if (r_fix_compleate && w_mode_normal)
             next_state  = P_R_V_AREA;
          else if (w_var_compleate_mask)
             next_state  = P_R_F_AREA;
          else if (r_last_read == 1'b1 && w_mode_normal)
             next_state  = P_R_V_AREA;
          else
             next_state  = P_R_F_AREA;
      P_R_F_AREA :
          if (i_hready == 1'b1 && w_rcnt == 3'd1)
             next_state  = P_R_INTVAL;
          else
             next_state  = P_R_F_AREA;
      P_R_F_AREA :
          if (i_hready == 1'b1 && w_rcnt == 3'd1 && w_mode_noraml)
             next_state  = P_R_INTVAL;
          else
             next_state  = P_R_V_AREA;
      P_R_CLR  :
             next_state  = P_R_IDLE;
      default    : 
             next_state  = P_R_IDLE;
  
      endcase
    

    assign w_rem_set      = (current_state == P_R_INTVAL) && (next_state == P_R_F_AREA | next_state == P_R_V_AREA);
    assign w_rem_dec      = (i_hready == 1'b1 && ((w_rcnt > 3'd1 && r_sel == 1'b1) || (w_rcnt == 3'd1)));
    assign w_fix_add_inc  = (i_hready == 1'b1 && (next_state == P_R_F_AREA && w_rcnt == 3'd2) || (next_state == P_R_F_AREA && w_start)) && w_fix_add != w_fix_add_e_last;
    assign w_var_add_inc  = (i_hready == 1'b1 && (next_state == P_R_F_AREA && w_rcnt == 3'd2) || (next_state == P_R_V_AREA && w_start)) && w_fix_add != w_fix_add_e_last;

    assign w_fix_add_skip = (w_fix_add == rg_rsv_fix_add_s) && (current_state != P_R_IDLE);
    assign w_var_add_skip = (w_fix_add == rg_rsv_var_add_s) && (current_state != P_R_IDLE);

    assign w_fix_add_update = (current_state == P_R_F_AREA && (i_hready == 1'b1 || w_start));
    assign w_var_add_update = (current_state == P_R_V_AREA && (i_hready == 1'b1 || w_start));

    

    assign w_start  = (w_rcnt != 3'd0) && (r_rcnt == 3'd0);
    assign w_send   = (w_rcnt = 3'dq) && i_hready;

    assign w_clr    = (current_state == P_R_CLR) && (next_state == P_R_IDLE);
    
    //AHB address
       always @(posedge hclk or negedge hresetn)
      if (~hresetn)
         r_add_out <= #P_dly  {32{1'b0}};
      else if (r_clr)
         r_add_out <= #P_dly  {32{1'b0}};
      else if(w_fix_add_update)
         r_add_out <= #P_dly  w_fix_add;
      else if(w_var_add_update)
         r_add_out <= #P_dly  w_var_add;
     

endmodule

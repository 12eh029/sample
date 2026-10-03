module EFDEC #(
   parameter P_EFDEC_HDATA_WITDTH          = 17'h10000,
   parameter P_EFDEC_VAR_BIT               = 6'd16,
   parameter P_EFDEC_FIX_BIT               = 6'd11,
   parameter P_EFDEC_HOUT_BIT              = 6'd16,
   parameter P_VOUT_BIT                    = 5,
   parameter P_EFDEC_FIX_CLANP             = 16'd2045,
   parameter P_EFDEC_TYPE_BIT              = 2'd2,
   parameter P_EFDEC_POLY                  = 32'hFFFF_FFFF,

   parameter P_EFDEC_INIT_VAL_DSTADDR      = 32'h0000_0000,
   parameter P_EFDEC_INIT_VAL_DSTCNTADDR   = 32'h0000_0000,
   parameter P_EFDEC_INIT_VAL_DFCTVNUM     = 16'd0,
   parameter P_EFDEC_INIT_VAL_FIXSTARTADDR = 32'h0000_0000,
   parameter P_EFDEC_INIT_VAL_FIXENDADDR   = 32'h0000_0000,
   parameter P_EFDEC_INIT_VAL_VARSTARTADDR = 32'h0000_0000,
   parameter P_EFDEC_INIT_VAL_VARENDADDR   = 32'h0000_0000
) (
   input          HRESETN,
   input          HCLK,
   input          PCLK,
   input          TENABLE,
   
   input   [ 7:2] PADDR,
   input   [ 3:0] PBSEL,
   input          PENABLE,
   input          PSEL,
   input   [31:0] PWDATA,
   input          PWRITE,
   output  [31:0] PRDATA,
   output         PREADY,
   
   
   output         HSEL0,
   output  [31:0] HADDR0,
   output  [ 1:0] HTRANS0,
   output         HWRITE0,
   output  [ 2:0] HSIZE0,
   output  [ 3:0] HBURST0,
   output  [31:0] HWDATA0,
   input   [31:0] HRDATA0,
   input          HREADY0,
   input          HRESP0,

   output         HSEL1,
   output  [31:0] HADDR1,
   output  [ 1:0] HTRANS1,
   output         HWRITE1,
   output  [ 2:0] HSIZE1,
   output  [ 3:0] HBURST1,
   output  [31:0] HWDATA1,
   input   [31:0] HRDATA1,
   input          HREADY1,
   input          HRESP
   
);

   parameter P_EFDEC_HADATA_BIT = $clog2( P_EFDEC_HDATA_WITDTH + 1'b1);
   parameter P_XYDATA_BIT       = P_EFDEC_VAR_BIT + P_EFDEC_FIX_BIT;
   parameter P_STAGE_NUM        = (P_EFDEC_HADATA_BIT+P_XYDATA_BIT);
   
   
   
   //----------------------------------------------------------------
   // Internal Signal
   //----------------------------------------------------------------
   wire            g_hclk;
   wire            w_rg_hclk_en;
   wire            g_pclk;
   wire            w_rg_start;
   wire            w_rg_restart;
   wire            w_rg_suspend;
   wire   [31:0]   w_rg_fix_add_s;
   wire   [31:0]   w_rg_fix_add_e;
   wire   [31:0]   w_rg_var_add_s;
   wire   [31:0]   w_rg_var_add_e;
   wire   [31:0]   w_rg_rsv_fix_add_s;
   wire   [31:0]   w_rg_rsv_fix_add_e;
   wire   [31:0]   w_rg_rsv_var_add_s;
   wire   [31:0]   w_rg_rsv_var_add_e;   
   wire            w_rg_clr;
   wire            w_fix_full;
   wire            w_var_full;
   wire   [31:0]   w_fix_data;   
   wire            w_fix_write_en;
   wire   [31:0]   w_var_data;   
   wire            w_var_write_en;
   wire            w_ahb_r_err;
   wire            w_ahb_r_busy;
   wire            w_fix_suspend;
   wire            w_var_suspend;
   wire            w_fix_fifo_empty;
   wire            w_fix_fifo_full;
   wire            w_var_fifo_empty;
   wire            w_var_fifo_full;   
   wire   [17:0]   w_fault_cnt;
   wire            w_ahb_w_comp;
   wire            w_ahb_w_err;
   wire            w_ahb_w_busy;
   wire   [31:0]   w_rx_fix_data;   
   wire            w_rx_var_datta;
   wire            w_fix_read_req;
   wire            w_var_read_req;
   wire   [17:0]   w_rg_fault_num;
   wire   [31:0]   w_rg_start_add;
   wire   [P_EFDEC_FIX_BIT-1:0]  w_conv_fix_data;
   wire            w_conv_fix_write_en;
   wire            w_fix_stop_req;
   wire   [ 5:0]   w_sft_cnt = P_EFDEC_FIX_BIT;
   
   //EFD_AHB_M_R
   wire                      w_read_compleat;
   wire                      w_ahb_r_fix_comp;
   wire                      w_ahb_r_var_comp;
   wire   [31:0]             w_rcvsign_result;
   
   wire                      w_rxmode_fix_read_req;
   wire                      w_rxmode_var_read_req;             
   wire   [31:0]             w_rxmode_fix_data;
   wire                      w_rxmode_fix_fifo_empty; 
   wire   [31:0]             w_rxmode_var_data;
   wire                      w_rxmode_var_fifo_empty; 

   wire   [P_EFDEC_VAR_BIT+P_EFDEC_FIX_BIT-1:0] w_dec_fault_data;
   wire                                         w_dec_valid;
   
   wire                                         w_tdec_stop_req;
   wire   [P_EFDEC_VAR_BIT+P_EFDEC_FIX_BIT-1:0] w_tdec_fault_data;
   wire   [P_EFDEC_TYPE_BIT-1:0]                w_tdec_fault_type;
   wire                                         w_tdec_vslid;
   wire                                         w_fault_id_err;
   
   wire                                         w_div_stop_req;
   wire   [P_EFDEC_HADATA_BIT+P_STAGE_NUM-1]    w_div_fault_data;
   wire   [P_EFDEC_TYPE_BIT-1:0]                w_div_fault_type;
   wire                                         w_div_valid;
   wire                                         w_div_valid_all;
   
   wire                                         w_tcnt_stop_req;
   wire   [32:0]                                w_tcnt_fault_data;
   wire                                         w_fault_cnt_err;
   
   wire   [32:0]                                w_txmode_fault_data;
   wire                                         w_txmode_fifo_write_en;
   wire                                         w_txmode_fifo_full;
   
   wire   [32:0]                                w_tx_fault_data;
   wire                                         w_tx_fifo_read_req;
   wire                                         w_tx_fifo_empty;
   wire                                         w_tx_fifo_full;
   wire                                         w_tx_fifo_write_en;
   
   wire   [14:0]                                w_fault_cnt_num;
   wire                                         w_ahb_w_fault_cnt_end_flg;
   wire                                         w_ahb_w_data_over_err;
   
   wire                                         w_rg_rcvsign_wr_en;
   wire                                         w_rg_rcvsign_init;
   wire   [1:0]                                 w_rg_efmode;
   wire                                         w_rg_dstcnt_start_add;
   wire                                         w_rg_vline_num;
   
   wire                                         g_hclk_normal;
   wire                                         g_hclk_dmac;
   wire                                         g_hclk_sign;




   
   
initial begin
   $display("DMYRD START!!");
end


EFD_AHB_M_R EFD_AHB_M_R (
   .hresetn             (g_hclk       ),
   .hclk                (HRSETN       ),
   .o_hsel              (HSEL0        ),
   .o_haddr             (HADDR0       ),
   .o_hwrite            (HWRITE0      ),
   .o_hsize             (HSIZE0       ),
   .o_hburst            (HBURST0[2:0] ),
   .o_htrans            (HTRANS0      ),
   .i_hready            (HREADY0      ),
   .i_hresp             (HRESP0       ),
   .i_hrdata            (HRDATA0      ),
   .rg_start            (w_rg_start         ),
   .rg_restart          (w_rg_restart       ),
   .rg_suspend          (w_rg_suspend       ),
   .rg_fix_add_s        (w_rg_fix_add_s     ),
   .rg_fix_add_e        (w_rg_fix_add_e     ),
   .rg_var_add_s        (w_rg_var_add_s     ),
   .rg_var_add_e        (w_rg_var_add_e     ),
   .rg_rsv_fix_add_s    (w_rg_rsv_fix_add_s ),
   .rg_rsv_fix_add_e    (w_rg_rsv_fix_add_e ),
   .rg_rsv_var_add_s    (w_rg_rsv_var_add_s ),
   .rg_rsv_var_add_e    (w_rg_rsv_var_add_e ),
   .rg_efmode           (w_rg_efmode        ),
   .o_read_comp         (w_read_compleat    ),
   .o_fix_data          (w_fix_data         ),
   .o_fix_write_en      (w_fix_write_en     ),
   .o_var_data          (w_var_data         ),
   .o_var_write_en      (w_var_write_en     ),
   .i_fix_full          (w_fix_full         ),
   .i_var_full          (w_var_full         ),
   .o_bus_err           (w_ahb_w_err        ),
   .o_busy              (w_ahb_w_busy       ),
   .o_fix_suspend       (w_fix_suspend      ),
   .o_var_suspend       (w_var_suspend      ),
   .i_fault_cnt_end_flg (w_ahb_w_fault_cnt_end_flg),
   .o_fix_comp          (w_ahb_r_fix_comp   ),
   .o_var_comp          (w_ahb_r_var_comp   ),
   .rg_clr              (w_rg_clr           )
);


endmodule

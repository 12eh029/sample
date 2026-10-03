module CPU (
  //clk,reset
  input CLK,
  input RSTn
);

initial  begin
   wait(RSTn);
   $display("[INFO]CPU start: %5t",$stime);
end

 typedef enum logic [2:0] {
    S_FETCH    = 3'd0,
    S_EXEC     = 3'd1,
    S_WAIT_DIV = 3'd2,
    S_WAIT_IO  = 3'd3,
    S_WAIT_MUL = 3'd4
  } state_t;

  state_t state;

  logic [15:0] pc;
  logic        pc_next;
  logic [15:0] instr;

  logic [3:0]        opcode;
  logic [3:0]        rd;
  logic [3:0]        rs;
  logic [3:0]        imm;

  logic [DATA_W-1:0] reg_rd; 
  logic [DATA_W-1:0] reg_rs;
  logic [DATA_W-1:0] alu_y;

  logic zf;
  logic nf;

  logic              reg_we;
  logic [3:0]        reg_waddr;
  logic [DATA_W-1:0] reg_wdata;

  logic [DATA_W-1:0] mem_rdata;
  logic              mem_we;

  logic div_start, div_busy, div_done;
  logic [DATA_W-1:0] div_q;

  logic mul_start, mul_busy, mul_done;
  logic [DATA_W-1:0] mul_p;

  instr_rom u_rom (
     .addr(pc),
     .data(instr)
  );

  assign opcode = instr[15:12];
  assign rd     = instr[11:8];
  assign rs     = instr[7:4];
  assign imm    = instr[3:0];

endmodule

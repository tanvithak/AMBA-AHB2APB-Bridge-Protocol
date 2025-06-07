module bridge_apb_controller(
 input logic HCLK,
 input logic HRESETn,

 input logic HWRITE,
 input logic HSELx,

 input logic [1:0]HTRANS,

 input logic [31:0]HADDR,
 input logic [31:0]HWDATA,
 input logic [31:0]PRDATA,

 output logic [31:0]HRDATA,
 output logic HREADY,
 output logic [1:0]HRESP,
 output logic [31:0]PADDR,
 output logic [31:0]PWDATA,
 output logic PSEL,
 output logic PENABLE,
 output logic PWRITE
);

 typedef enum logic[2:0] {IDLE,READ,W_WAIT,WRITE,WRITE_P,WENABLE_P,WENABLE,RENABLE}state; 

 state cs,ns;

 logic valid;//Given by AHB module to bridge; decides which state the system needs to be (valid = 1 if HTRANS = 01 OR 10)


 logic [31:0]haddr;
 logic hwrite;

 always_ff@(posedge HCLK)
  begin
   if(!HRESETn)
    cs <= IDLE;
   else
    cs <= ns;
  end


 //next state logic
 always_comb
  begin
   ns = cs;
   HREADY_NXT = 1;
   unique case(cs)
    IDLE      : begin
                 if(valid == 1 && HWRITE == 1)
                  begin
                   ns = W_WAIT;
                   HREADY_NXT = 1;
                  end
                 else if(valid == 1 && HWRITE == 0)
                  begin
                   ns = READ;
                   HREADY_NXT = 0;
                  end
                end
    READ      : begin
                 ns = RENABLE;
                 HREADY_NXT = 1;
                end
    W_WAIT    : begin
                 HREADY_NXT = 0;
                 if(valid)
                  begin 
                   ns = WRITE_P;
                   HREADY_NXT = 0;
                  end
                 else if(valid == 0)
                  begin
                   ns = WRITE;
                   HREADY_NXT = 0;
                  end
                end
    WRITE     : begin
                 HREADY_NXT = 0;
                 if(valid == 0 || HWRITE == 1)
                  ns = WENABLE;
                 else
                  ns = WENABLE_P;
                end
    WRITE_P   : begin
                 ns = WENABLE_P;
                 if(HWRITE_REG)
                  HREADY_NXT = 1;
                 else
                  HREADY_NXT = 0;
                end
    WENABLE_P : begin
                 HREADY_NXT = 0;
                 if(!HWRITE_REG_D2)
                  ns = READ;
                 else if(valid)
                  ns = WRITE_P;
                 else if(HWRITE == 0)
                  ns = WRITE; 
                end
    WENABLE   : begin
                 HREADY_NXT = 0;
                 if( {valid,HWRITE} == 2'b10 )
                  ns = READ;
                 else if( {valid,HWRITE} == 2'b11 )
                  ns = W_WAIT;
                 else if(valid == 0)
                  ns = IDLE;
                end
    RENABLE   : begin
                 if(valid == 0)
                  ns = IDLE;
                 else if( {valid,HWRITE} == 2'b11 )
                  begin
                   ns = W_WAIT;
                   HREADY_NXT = 1;
                  end
                 else if( {valid,HWRITE} == 2'b10 )
                  ns = READ;
                end

   endcase
  end




 //output logic
  always_comb
  begin
   PSEL = (de_select_slave) ? 0 : PSEL;
   unique case(cs)
    IDLE      : begin
                 PSEL = 0;
                 PENABLE = 0;
                 PWRITE = 0;
                end
    READ      : begin
                 PSEL = 0;
                 PWRITE = 0;
                 PENABLE = 0;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    W_WAIT    : begin
                 PENABLE = 0;
                 PWRITE = 0;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    WRITE     : begin
                 PSEL = 0;
                 PENABLE = 0;
                 PWRITE = 1;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    WRITE_P   : begin
                 PWRITE = 1;
                 PENABLE = 0;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    WENABLE_P : begin
                 PENABLE = 1;
                 PWRITE = PWRITE;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    WENABLE   : begin
                 PENABLE = 1;
                 PWRITE = PWRITE;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    RENABLE   : begin
                 PENABLE = 1;
                 PWRITE = PWRITE;
                 if(flag_timer)
                  PSEL[0] = 1;
                 else if(flag_interruptc)
                  PSEL[1] = 1;
                 else if(flag_remap_pause_controller)
                  PSEL[2] = 1;
                 if(flag_slave4)
                  PSEL[3] = 1;
                end
    default   : begin
                 PENABLE = PENABLE;
                 PWRITE = PWRITE;
                 PSELx = 0;
                end 

   endcase
  end
endmodule

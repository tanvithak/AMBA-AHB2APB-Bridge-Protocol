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
   unique case(cs)
    IDLE      : begin
                 if(valid == 1 && HWRITE == 1)
                  ns = W_WAIT;
                 else if(valid == 1 && HWRITE == 0)
                  ns = READ;
                end
    READ      : ns = RENABLE;
    W_WAIT    : begin
                 if(valid)
                  ns = WRITE_P;
                 else if(valid == 0)
                  ns = WRITE;
                end
    WRITE     : begin
                 if(valid == 0)
                  ns = WENABLE;
                 else if(valid == 1)
                  ns = WENABLE_P;
                end
    WRITE_P   : ns = WENABLE_P;
    WENABLE_P : begin
                 if( {valid,HWRITE} == 2'b01)
                  ns = WRITE;
                 else if( {valid,HWRITE} == 2'b11)
                  ns = WRITE_P;
                 else if(HWRITE == 0)
                  ns = READ; 
                end
    WENABLE   : begin
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
                  ns = WRITE_P;//OR W_WAIT
                 else if( {valid,HWRITE} == 2'b10 )
                  ns = READ;
                end

   endcase
  end




 //output logic
  always_comb
  begin
   unique case(cs)
    IDLE      : begin
                 PSEL = 0;
                 PENABLE = 0;
                 PADDR = 0;
                 PWRITE = 0;
                end
    READ      : begin
                 PADDR = HADDR;
                 PSEL = 0;
                 PWRITE = 0;
                 PENABLE = 0;
                 if(flag_timer)
                  PSEL[0] = 1;
                end
    W_WAIT    : begin
                 PENABLE = 0;
                 haddr = HADDR;
                 hwrite = HWRITE;
                end
    WRITE     : begin
                 PADDR = haddr;
                 PSEL = 1;
                 PENABLE = 0;
                 PWRITE = 1;
                 HREADY = 0;
                end
    WRITE_P   : begin
                 PADDR = haddr;
                 PSEL = 1;
                 PWRITE = 1;
                 PWDATA = HWDATA;
                 PENABLE = 0;
                 HREADY = 0;
                 hwrite = HWRITE;
                end
    WENABLE_P : begin
                 PENABLE = 1;
                 HREADY = 1;
                end
    WENABLE   : begin
                 PENABLE = 1;
                 HREADY = 1;
                end
    RENABLE   : begin
                 PENABLE = 1;
                 HRDATA = PRDATA;
                 HREADY = 1;
                end

   endcase
  end
endmodule

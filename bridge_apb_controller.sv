`include "definitions.sv"

module bridge_apb_controller(
 input logic HCLK,
 input logic HRESETn,
 input logic valid,
 input logic HWRITE,
 input logic [2:0] HSIZE,

 input logic [1:0]HTRANS,

 input logic [31:0] HADDR,
 input logic [`WIDTH-1:0] HWDATA,
 input logic [`WIDTH-1:0] PRDATA,
 input logic [`WIDTH-1:0] CONFIG_REG_DATA,
 input logic [`WIDTH-1:0] HADDR_REG_D1,
 input logic [`WIDTH-1:0] HADDR_REG_D2,
 input logic [`WIDTH-1:0] HADDR_REG_D3,
 input logic [`WIDTH-1:0] INC_ADDR,

 input logic flag_timer,
 input logic flag_interruptc, 
 input logic flag_remap_pause_controller,
 input logic flag_slave4,

 output logic [`WIDTH-1:0] HRDATA,
 output logic HREADY_OUT,
 output logic [`WIDTH-1:0] PADDR,
 output logic [`WIDTH-1:0] PWDATA,
 output logic [`SLAVES-1:0] PSEL,
 output logic PENABLE,
 output logic PWRITE
);

 typedef enum logic[2:0] {IDLE,READ,W_WAIT,WRITE,WRITE_P,WENABLE_P,WENABLE,RENABLE}state; 



 state cs_reg1,cs_reg,cs,ns;



 //valid signal: Given by AHB slave module; decides which state the system needs to be (valid = 1 if HTRANS = 01 OR 10)


 logic HREADY_NXT;


//COUNTER LOGIC REGISTERS AND VARIABLES
logic count_write,count_read,count_read_d2,count_write_d2,count_write_d3,count_write_d4,count_write_wait,count_write_wait_d2,count_write_wait_d3,count_write_wait_d4;



 logic de_select_slave,de_select_slave1,de_select_slave2;



 logic [2:0] HSIZE_REG;
 logic [2:0] HSIZE_REG_D2;
 logic [2:0] HSIZE_REG_D3;
 logic [2:0] HSIZE_REG_D4;
 logic [2:0] HSIZE_REG_D5;

 logic [1:0] HTRANS_REG;

 integer count ;
 logic [WIDTH-1:0] HWDATA_REG_D1;  //Delayed by one cycle
 logic [WIDTH-1:0] HWDATA_REG_D2;  //Delayed by two cycle


 logic HWRITE_REG,
 logic HWRITE_REG_D2;
 logic HWRITE_REG_D3;
 logic HWRITE_REG_D4;
 logic HWRITE_REG_D5;
 logic HWRITE_REG_D6;




//INITIALISING AND STORING VALUES IN HWRITE, HSIZE, counter REGISTERS

 always_ff@(posedge HCLK, negedge HRESETn)
  begin
   if(!HRESTn)
    begin
     HWRITE_REG <= 0;
     HWRITE_REG_D2 <= 0;
     HWRITE_REG_D3 <= 0;
     HWRITE_REG_D4 <= 0;
     HWRITE_REG_D5 <= 0;
     HWRITE_REG_D6 <= 0;

     HTRANS_REG <= 0;

     HSIZE_REG <= 0;
     HSIZE_REG_D2 <= 0;
     HSIZE_REG_D3 <= 0;
     HSIZE_REG_D4 <= 0;
     HSIZE_REG_D5 <= 0;


     count_write_d2 <= 0;
     count_write_d3 <= 0;
     count_write_d4 <= 0;

     count_read_d2 <= 0;

     count_write_wait_d2 <= 0;
     count_write_wait_d3 <= 0;
     count_write_wait_d4 <= 0;
    end
   else
    begin
     HWRITE_REG <= HWRITE;
     HWRITE_REG_D2 <= HWRITE_REG;
     HWRITE_REG_D3 <= HWRITE_REG_D2;
     HWRITE_REG_D4 <= HWRITE_REG_D3;
     HWRITE_REG_D5 <= HWRITE_REG_D4;
     HWRITE_REG_D6 <= HWRITE_REG_D5;

     HTRANS_REG <= HTRANS;

     HSIZE_REG <= HSIZE;
     HSIZE_REG_D2 <= HSIZE_REG;
     HSIZE_REG_D3 <= HSIZE_REG_D2;
     HSIZE_REG_D4 <= HSIZE_REG_D3;
     HSIZE_REG_D5 <= HSIZE_REG_D4;


     count_write_d2 <= count_write;
     count_write_d3 <= count_write_d2;
     count_write_d4 <= count_write_d3;

     count_read_d2 <= count_read;

     count_write_wait_d2 <= count_write_wait;
     count_write_wait_d3 <= count_write_wait_d2;
     count_write_wait_d4 <= count_write_wait_d3;
    end
  end



   






 //Deselecting slave blocks

 always@(PADDR)
  begin
   if(PADDR <= 8)
    de_select_slave <= 1;
   else
    de_select_slave <= 0;
  end

 always_ff@(posedge HCLK)
  begin
   de_select_slave1 <= de_select_slave;
   de_select_slave2 <= de_select_slave1;
  end






//COUNTER LOGIC FOR COUNTING WRITES
 always_ff@(posedge HCLK, negedge HRESETn)
  begin
   if(!HRESETn)
    count_write <= 0;
   else if(valid && (cs == IDLE) && HWRITE)
    count_write <= count_write + 1;
   else
    count_write <= 0;
  end


//COUNTER LOGIC FOR COUNTING READS
 always_ff@(posedge HCLK, negedge HRESETn)
  begin
   if(!HRESETn)
    count_read <= 0;
   else if(valid && (cs == IDLE) && !HWRITE)
    count_read <= count_read + 1;
   else
    count_read <= 0;
  end



//COUNTER LOGIC for counting wait states
 always_ff@(posedge HCLK, negedge HRESETn)
  begin
   if(!HRESETn)
    count_write_wait <= 0;
   else if(valid && (cs == RENABLE) && !HWRITE)
    count_write_wait <= count_write_wait + 1;
   else
    count_write_wait <= 0;
  end







//Pipelining of the states stages
//Also includes initialising HWDATA registers for wait conditions
 always_ff@(posedge HCLK, negedge HRESETn)
  begin
   if(!HRESETn)
    begin
     cs <= IDLE;
     cs_reg <= 0;
     cs_reg1 <= 0;
     HREADY_OUT <= 1;
     HWDATA_REG_D1 <= 0;
     HWDATA_REG_D2 <= 0;
    end
   else
    begin
     cs <= ns;
     cs_reg <= cs;
     cs_reg1 <= cs_reg;
     HREADY_OUT <= HREADY_NXT;
     HWDATA_REG_D1 <= HWDATA;
     HWDATA_REG_D2 <= HWDATA_REG_D1;
    end
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




 //Little Endianness on HWDATA and effect on PWDATA
  task endianess(input [2:0]hsize,input [31:0]hwdata,input [1:0]addr);
   begin
    case(hsize)
     3'b000  : begin
                case(addr)
                 `ADDR_OFFSET_BYTE_0 : PWDATA = hwdata[7:0];
                 `ADDR_OFFSET_BYTE_1 : PWDATA = hwdata[15:8];
                 `ADDR_OFFSET_BYTE_2 : PWDATA = hwdata[23:16];
                 `ADDR_OFFSET_BYTE_3 : PWDATA = hwdata[31:24];
                  default            : PWDATA = 0;
                endcase
               end
     3'b001  : begin
                case(addr)
                 `ADDR_OFFSET_HFWORD_0 : PWDATA = hwdata[15:0];
                 `ADDR_OFFSET_HFWORD_2 : PWDATA = hwdata[31:16];
                  default              : PWDATA = 0;
                endcase
               end
     3'b010  : begin
                 case(addr)
                   `ADDR_OFFSET_WORD : PWDATA = hwdata;
                    default          : PWDATA = 0;
                 endcase
               end
     default : PWDATA = 0;
    endcase
   end
  endtask






  //Little Endianness on PRDATA
 task endianess_read(input [2:0]hsize,input [1:0]addr);
   begin
    case(hsize)
     3'b000  : begin
                case(addr)
                 `ADDR_OFFSET_BYTE_0 : HRDATA = PRDATA[7:0];
                 `ADDR_OFFSET_BYTE_1 : HRDATA = PRDATA[15:8];
                 `ADDR_OFFSET_BYTE_2 : HRDATA = PRDATA[23:16];
                 `ADDR_OFFSET_BYTE_3 : HRDATA = PRDATA[31:24];
                  default            : HRDATA = 0;
                endcase
               end
     3'b001  : begin
                case(addr)
                 `ADDR_OFFSET_HFWORD_0 : HRDATA = PRDATA[15:0];
                 `ADDR_OFFSET_HFWORD_2 : HRDATA = PRDATA[31:16];
                  default              : HRDATA = 0;
                endcase
               end
     3'b010  : begin
                 case(addr)
                   `ADDR_OFFSET_WORD : HRDATA = PRDATA;
                    default          : HRDATA = 0;
                 endcase
               end
     default : HRDATA = 0;
    endcase
   end
  endtask
endmodule

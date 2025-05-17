module bridge_design(
 input logic BCLK,
 input logic BRESETn,

 input logic HWRITE,
 input logic HSELx,

 input logic HTRANS[1:0],

 input logic HADDR[31:0],
 input logic HWDATA[31:0],
 input logic PRDATA[31:0],

 output logic HRDATA[31:0],
 output logic HREADY,
 output logic HRESP[1:0],
 output logic PSEL,
 output logic PENABLE,
 output logic PWRITE,
 output logic PSEL,
);

 typdef enum logic[2:0] {IDLE,READ,W_WAIT,WRITE,WRITE_P,WENABLE_P,WENABLE,RENABLE}state; 
endmodule

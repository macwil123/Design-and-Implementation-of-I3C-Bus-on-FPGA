`timescale 1ns / 1ps

module i3c_tb;

// Inputs
reg clk;
reg rst;
reg [6:0] addr;
reg [7:0] data_in;
reg enable;
reg rw;

// Outputs
wire [7:0] data_out;
wire ready;

// Bidirs
wire i3c_sda;
wire i3c_scl;

// Instantiate the Unit Under Test (UUT)
i3c_controller master(
.clk(clk),
.rst(rst),
.dynamic_addr(addr),
.enable(enable),
.rw(rw),
.ready(ready),
.i3c_sda(i3c_sda),
.i3c_scl(i3c_scl)
//.data_in(data_in)
);


i3c_slave_controller slave(
    .sda(i3c_sda),
    .scl(i3c_scl),
    .clk(clk)
    );

initial begin
clk = 0;
forever begin
clk = #5 ~clk;
end
end
   
   


  //TB FOR WRITE OPERATION
initial begin
// Initialize Inputs
rst = 1;

// Wait 200 ns for global reset to finish
 #200;
       
// Add stimulus here
rst = 0;
addr = 7'b0101010;
//data_in = 8'b11111110;
rw = 0;
enable = 1;
#20000;
enable =0;

#10000;

$finish;
end


//WRITE OPERATION ENDS HERE

/*
//TB FOR READ OPERATION BEGINS
initial
begin

rst = 1;

#100;

rst=0;
addr = 7'b0101010;
rw=1;
enable=1;

#10;

       enable= 0;

#300;
$display("The value recieved from the slave is %b",data_out);





$finish; end
//READ OPERATION TB ENDS HERE
  */
endmodule

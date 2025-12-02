/*
The i3c_fpga module serves as the top-level integration of an I3C master and an I3C slave implemented on an FPGA.
It interfaces with external control inputs such as clock, reset, read/write selection, enable signal, and a 7-bit dynamic address that is assigned to the slave.
This module connects the internal i3c_controller master logic and the i3c_slave_controller through shared SDA and SCL lines, enabling on-chip I3C communication.
The master drives the I3C clock (i3c_scl) and bidirectional data line (i3c_sda) to initiate and manage bus transactions, 
while the slave monitors and responds through its own sda and scl interface. A ready output indicates the completion of master operations. 
This wrapper enables seamless master-slave communication within the FPGA using standard I3C signaling.

*/
`timescale 1ns / 1ps
module i3c_fpga(
input  clk,
input  rst,
input  [6:0] dynamic_addr,
input  enable,
input  rw,

output  ready,

//Master
inout i3c_sda,
output  i3c_scl,
   


//Slave
input scl,
inout sda
 );
    
    
    
    
    
   

    
   i3c_controller master (
    .clk(clk),
    .rst(rst),
    .dynamic_addr(dynamic_addr),
    .enable(enable),
    .rw(rw),
    .ready(ready),
    .i3c_sda(i3c_sda),
    .i3c_scl(i3c_scl)

    
    );
    
    
    i3c_slave_controller slave (
        .sda(sda),
        .scl(scl),
        .clk(clk)
        );
        
        
endmodule

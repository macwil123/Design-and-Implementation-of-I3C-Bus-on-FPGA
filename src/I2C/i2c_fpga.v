/*
Module: i2c_fpga Brief: Top-level integration module for I2C master and slave on FPGA. 
Description: This module instantiates the I2C master (i2c_controller) and I2C slave (i2c_slave_controller),
and connects them through SDA and SCL lines routed via external PMOD pins. 
The master generates the I2C bus signals including START, STOP, addressing, ACK/NACK and data transfer. 
The slave detects start and stop conditions, interprets addressing, and performs data reception or transmission based on the R/W bit. 
Internal signals were captured using ILA to verify bus transactions. 
The design forms a complete closed-loop I2C communication system on a single FPGA board for hardware-level testing and verification.

*/

`timescale 1ns / 1ps
module i2c_fpga(
input  clk,
input  rst,
input  [6:0] addr,
input  enable,
input  rw,

output  ready,

//Master
inout i2c_sda,
output  i2c_scl,
   


//Slave
input scl,
inout sda
 );
    
    
    
    
    
   

    
   i2c_controller master (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .enable(enable),
    .rw(rw),
    .ready(ready),
    .i2c_sda(i2c_sda),
    .i2c_scl(i2c_scl)
    
    );
    
    
    i2c_slave_controller slave (
        .sda(sda),
        .scl(scl),
        .clk(clk)
        );
        
        
endmodule

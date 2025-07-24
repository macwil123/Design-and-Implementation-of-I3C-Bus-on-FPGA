`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 12:24:42
// Design Name: 
// Module Name: slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module slave(
    
    input clk_recieve,
    output flag
    );
    
    reg [7:0]counter =0;
    reg flag_slave=0;
    
    assign flag = flag_slave;
    always @(posedge clk_recieve)
    begin
    
        if(counter == 9) begin
           flag_slave <=1;
           counter <= 0;
           end
           
        else   begin
        
        counter <= counter + 1;
        if(flag_slave == 1)  flag_slave <=0;
        
        end 
    end
    
endmodule

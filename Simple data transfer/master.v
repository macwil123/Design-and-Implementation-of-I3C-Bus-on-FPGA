`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 11:19:10
// Design Name: 
// Module Name: master
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


module master(

input clk,
output clk_slow


);
    
    
    reg clk_divide = 0;
    reg [3:0] counter =0;
    parameter divide_by =1000000;
    
    assign clk_slow = clk_divide; 
    
    always @(posedge clk)
    begin
        if(counter == (divide_by/2)-1)
            begin
                clk_divide <= ~clk_divide;
                counter <= 0;
            end
            
    else counter <= counter + 1;
         end      
         
         
             
endmodule

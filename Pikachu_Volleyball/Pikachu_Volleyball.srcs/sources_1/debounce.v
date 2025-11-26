`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/20 00:14:16
// Design Name: 
// Module Name: debounce
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


module debounce(
    input clk,
    input btn_input,
    output btn_output
);
    parameter DEBOUNCE_PERIOD = 2_000_000;
    reg [20:0] counter;
    assign btn_output = (counter == DEBOUNCE_PERIOD);
    always@(posedge clk) begin
        if (btn_input == 0) counter <= 0;
        else counter <= counter + (counter != DEBOUNCE_PERIOD);
    end
endmodule

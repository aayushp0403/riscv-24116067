`timescale 1ns/1ps
module alu_24116067(
    input wire [31:0] a,b,
    input wire [3:0] alu_sel,
    output reg [31:0] result
);
    always@(*)begin
        case(alu_sel)
            4'd0:result=a+b;
            4'd1:result=a-b;
            4'd2:result=a<<b[4:0];
            4'd3:result=($signed(a)<$signed(b))?32'b1:32'b0;
            4'd4:result=(a<b)?32'b1:32'b0;
            4'd5:result=a^b;
            4'd6:result=a>>b[4:0];
            4'd7:result=$signed(a)>>>b[4:0];
            4'd8:result=a|b;
            4'd9:result=a&b;
            default:result=32'b0;
        endcase
    end
endmodule
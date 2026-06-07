`timescale 1ns/1ps
module regfile_24116067(
    input wire clk,reset,we,
    input wire [4:0] rs1,rs2,rd,
    input wire [31:0] wdata,
    output wire [31:0] rdata1,rdata2
);
    reg [31:0] r_file [0:31];
    integer i;
    assign rdata1=(rs1!=5'b0)?r_file[rs1]:32'b0;
    assign rdata2=(rs2!=5'b0)?r_file[rs2]:32'b0;
    always@(posedge clk)begin
        if(!reset)begin
            for(i=0;i<32;i=i+1)r_file[i]<=32'b0;
        end else if(we&&(rd!=5'b0))begin
            r_file[rd]<=wdata;
        end
    end
endmodule
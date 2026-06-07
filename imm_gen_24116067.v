`timescale 1ns/1ps
module imm_gen_24116067(
    input wire [31:0] IR,
    output reg [31:0] imm
);
    wire [6:0] opcode=IR[6:0];
    wire [2:0] funct3=IR[14:12];
    always@(*)begin
        if(opcode==7'b0010011)begin
            if(funct3==3'b101)imm={27'b0,IR[24:20]};
            else imm={{20{IR[31]}},IR[31:20]};
        end else if((opcode==7'b1100111)||(opcode==7'b0000011))begin
            imm={{20{IR[31]}},IR[31:20]};
        end else if(opcode==7'b0100011)begin
            imm={{20{IR[31]}},IR[31:25],IR[11:7]};
        end else if((opcode==7'b0010111)||(opcode==7'b0110111))begin
            imm={IR[31:12],12'b0};
        end else if(opcode==7'b1100011)begin
            imm={{20{IR[31]}},IR[7],IR[30:25],IR[11:8],1'b0};
        end else if(opcode==7'b1101111)begin
            imm={{12{IR[31]}},IR[19:12],IR[20],IR[30:21],1'b0};
        end else imm=32'b0;
    end
endmodule
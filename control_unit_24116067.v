`timescale 1ns/1ps
module control_unit_24116067(
    input wire clk,reset,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire funct7,beq,blt,bltu,
    output reg pc_en,ir_en,mem_write,adr_src,branch_taken,reg_we,immed_taken,pc_taken,mem_rstrb,
    output reg [1:0] regw_sel,
    output reg [3:0] alu_sel
);
    always@(*)begin
        if(opcode==7'b0110011)begin
            case(funct3)
                3'b000:alu_sel=funct7?4'd1:4'd0;
                3'b001:alu_sel=4'd2;
                3'b010:alu_sel=4'd3;
                3'b011:alu_sel=4'd4;
                3'b100:alu_sel=4'd5;
                3'b101:alu_sel=funct7?4'd7:4'd6;
                3'b110:alu_sel=4'd8;
                3'b111:alu_sel=4'd9;
            endcase
        end else if(opcode==7'b0010011)begin
            case(funct3)
                3'b000:alu_sel=4'd0;
                3'b001:alu_sel=4'd2;
                3'b010:alu_sel=4'd3;
                3'b011:alu_sel=4'd4;
                3'b100:alu_sel=4'd5;
                3'b101:alu_sel=funct7?4'd7:4'd6;
                3'b110:alu_sel=4'd8;
                3'b111:alu_sel=4'd9;
            endcase
        end else begin
            alu_sel=4'd0;
        end
    end
    localparam FETCH=2'd0;
    localparam DECODE=2'd1;
    localparam EXECUTE=2'd2;
    localparam MEM_WAIT=2'd3;
    reg [1:0] state,next_state;
    always@(posedge clk)begin
        if(!reset)state<=FETCH;
        else state<=next_state;
    end
    always@(*)begin
        next_state=state;
        pc_en=0;ir_en=0;mem_rstrb=0;mem_write=0;adr_src=0;
        branch_taken=0;reg_we=0;immed_taken=0;pc_taken=0;regw_sel=0;
        case(state)
            FETCH:begin
                mem_rstrb=1'b1;
                adr_src=1'b0;
                next_state=DECODE;
            end
            DECODE:begin
                ir_en=1'b1;
                next_state=EXECUTE;
            end
            EXECUTE:begin
                case(opcode)
                    7'b0010011:begin reg_we=1;immed_taken=1;regw_sel=2'b01;pc_en=1;next_state=FETCH;end
                    7'b0110011:begin reg_we=1;regw_sel=2'b01;pc_en=1;next_state=FETCH;end
                    7'b0110111:begin reg_we=1;regw_sel=2'b11;pc_en=1;next_state=FETCH;end
                    7'b1100111:begin branch_taken=1;reg_we=1;immed_taken=1;regw_sel=2'b10;pc_en=1;next_state=FETCH;end
                    7'b1101111:begin branch_taken=1;reg_we=1;immed_taken=1;pc_taken=1;regw_sel=2'b10;pc_en=1;next_state=FETCH;end
                    7'b0010111:begin reg_we=1;immed_taken=1;pc_taken=1;regw_sel=2'b01;pc_en=1;next_state=FETCH;end
                    7'b1100011:begin
                        immed_taken=1;pc_taken=1;regw_sel=2'b00;
                        case(funct3)
                            3'b000:branch_taken=beq;
                            3'b001:branch_taken=~beq;
                            3'b100:branch_taken=blt;
                            3'b101:branch_taken=~blt;
                            3'b110:branch_taken=bltu;
                            3'b111:branch_taken=~bltu;
                            default:branch_taken=0;
                        endcase
                        pc_en=1;next_state=FETCH;
                    end
                    7'b0100011:begin mem_write=1;adr_src=1;immed_taken=1;pc_en=1;next_state=FETCH;end
                    7'b0000011:begin mem_rstrb=1;adr_src=1;immed_taken=1;next_state=MEM_WAIT;end
                    default:next_state=FETCH;
                endcase
            end
            MEM_WAIT:begin
                reg_we=1;regw_sel=2'b00;pc_en=1;immed_taken=1;
                next_state=FETCH;
            end
        endcase
    end
endmodule
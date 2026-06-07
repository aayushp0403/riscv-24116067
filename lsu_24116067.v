`timescale 1ns/1ps
module lsu_24116067(
    input wire [2:0] funct3,
    input wire [1:0] addr_align,
    input wire [31:0] mem_rdata,rs2_data,
    output reg [31:0] load_data_out,store_data_out,
    output reg [3:0] lsu_wmask
);
    wire [31:0] shifted_load=mem_rdata>>{addr_align,3'b000};
    always@(*)begin
        case(funct3)
            3'b000:load_data_out={{24{shifted_load[7]}},shifted_load[7:0]};
            3'b001:load_data_out={{16{shifted_load[15]}},shifted_load[15:0]};
            3'b100:load_data_out={24'b0,shifted_load[7:0]};
            3'b101:load_data_out={16'b0,shifted_load[15:0]};
            default:load_data_out=shifted_load;
        endcase
        case(funct3)
            3'b000:begin
                store_data_out=rs2_data<<{addr_align,3'b000};
                lsu_wmask=4'b0001<<addr_align;
            end
            3'b001:begin
                store_data_out=rs2_data<<{addr_align[1],4'b0000};
                lsu_wmask=4'b0011<<{addr_align[1],1'b0};
            end
            3'b010:begin
                store_data_out=rs2_data;
                lsu_wmask=4'b1111;
            end
            default:begin
                store_data_out=32'b0;lsu_wmask=4'b0000;
            end
        endcase
    end
endmodule
`timescale 1ns/1ps
module riscv_processor#(
    parameter RESET_ADDR=32'h00000000,
    parameter ADDR_WIDTH=32
)(
    input wire clk,reset,
    output wire [31:0] mem_addr,mem_wdata,
    output wire [3:0] mem_wmask,
    input wire [31:0] mem_rdata,
    output wire mem_rstrb,
    input wire mem_rbusy,mem_wbusy
);
    reg [31:0] pc,IR;
    wire [31:0] imm;
    wire [6:0] opcode=IR[6:0];
    wire [2:0] funct3=IR[14:12];
    wire funct7=IR[30];
    wire [4:0] rs1=IR[19:15];
    wire [4:0] rs2=IR[24:20];
    wire [4:0] rd=IR[11:7];
    wire [31:0] pcnext;
    wire [31:0] pcplus4=pc+32'd4;
    wire [31:0] rgd_data,rs1_data,rs2_data,alu_input1,alu_input2,alu_result;
    wire blt,beq,bltu;
    wire pc_en,ir_en,mem_write,adr_src,branch_taken,reg_we,immed_taken,pc_taken;
    wire [1:0] regw_sel;
    wire [3:0] alu_sel;
    wire [31:0] load_data_out,store_data_out;
    wire [3:0] lsu_wmask;
    wire [1:0] addr_align=alu_result[1:0];
    always@(posedge clk)begin
        if(!reset)pc<=RESET_ADDR;
        else if(pc_en)pc<=pcnext;
    end
    always@(posedge clk)begin
        if(ir_en)IR<=mem_rdata;
    end
    assign mem_addr=(adr_src)?alu_result:pc;
    assign mem_wmask=(mem_write)?lsu_wmask:4'b0000;
    assign mem_wdata=store_data_out;
    assign alu_input1=(pc_taken)?pc:rs1_data;
    assign alu_input2=(immed_taken)?imm:rs2_data;
    assign pcnext=(branch_taken)?(alu_result&~32'h00000001):pcplus4;
    assign rgd_data=(regw_sel==2'b00)?load_data_out:(regw_sel==2'b01)?alu_result:(regw_sel==2'b10)?pcplus4:imm;
    assign beq=(rs1_data==rs2_data);
    assign blt=($signed(rs1_data)<$signed(rs2_data));
    assign bltu=(rs1_data<rs2_data);
    alu_24116067 u_alu(.a(alu_input1),.b(alu_input2),.alu_sel(alu_sel),.result(alu_result));
    regfile_24116067 u_regfile(.clk(clk),.reset(reset),.we(reg_we),.rs1(rs1),.rs2(rs2),.rd(rd),.wdata(rgd_data),.rdata1(rs1_data),.rdata2(rs2_data));
    imm_gen_24116067 u_imm_gen(.IR(IR),.imm(imm));
    lsu_24116067 u_lsu(.funct3(funct3),.addr_align(addr_align),.mem_rdata(mem_rdata),.rs2_data(rs2_data),.load_data_out(load_data_out),.store_data_out(store_data_out),.lsu_wmask(lsu_wmask));
    control_unit_24116067 u_control(.clk(clk),.reset(reset),.opcode(opcode),.funct3(funct3),.funct7(funct7),.beq(beq),.blt(blt),.bltu(bltu),.pc_en(pc_en),.ir_en(ir_en),.mem_write(mem_write),.adr_src(adr_src),.branch_taken(branch_taken),.reg_we(reg_we),.immed_taken(immed_taken),.pc_taken(pc_taken),.regw_sel(regw_sel),.alu_sel(alu_sel),.mem_rstrb(mem_rstrb));
endmodule
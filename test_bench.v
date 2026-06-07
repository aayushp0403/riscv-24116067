//==============================================================================
// RISC-V Processor Testbench - Extended 20-Test Suite
// Multi-cycle processor with memory busy signals
//==============================================================================

`timescale 1ns/1ps

module riscv_testbench;

    //==========================================================================
    // Clock and Reset
    //==========================================================================
    reg clk;
    reg reset;
    
    //==========================================================================
    // Memory Interface Signals
    //==========================================================================
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    reg         mem_rbusy;
    reg         mem_wbusy;
    
    //==========================================================================
    // Memory Arrays
    //==========================================================================
    reg [31:0] memory [0:4095];  // 16KB unified memory
    
    //==========================================================================
    // Test Control Variables
    //==========================================================================
    integer test_num;
    integer passed_tests;
    integer total_tests;
    integer cycle_count;
    integer i;
    
    //==========================================================================
    // Instantiate RISC-V Processor
    //==========================================================================
    riscv_processor #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(32)
    ) uut (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset(reset)
    );
    
    //==========================================================================
    // Clock Generation (10ns period = 100MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //==========================================================================
    // Memory Model (simplified - no wait states)
    //==========================================================================
    
    reg [31:0] read_data;
    
    // Memory read
    always @(posedge clk) begin
        if (mem_rstrb) begin
            read_data <= memory[mem_addr[31:2]];
        end
    end
    
    assign mem_rdata = read_data;
    
    // Memory write with byte masking
    always @(posedge clk) begin
        if (mem_wmask != 4'b0000) begin
            if (mem_wmask[0]) memory[mem_addr[31:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) memory[mem_addr[31:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) memory[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) memory[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
        end
    end
    
    // Memory busy signals (no wait states for this simple testbench)
    always @(*) begin
        mem_rbusy = 0;
        mem_wbusy = 0;
    end
    
    //==========================================================================
    // Cycle Counter
    //==========================================================================
    always @(posedge clk) begin
        if (!reset)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end
    
    //==========================================================================
    // Helper Tasks
    //==========================================================================
    
    // Initialize memory
    task init_memory;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                memory[i] = 32'h00000013;  // NOP (ADDI x0, x0, 0)
            end
        end
    endtask
    
    // Reset processor
    task reset_processor;
        begin
            reset = 0;
            @(posedge clk);
            @(posedge clk);
            reset = 1;
            cycle_count = 0;
        end
    endtask
    
    // Run for N cycles
    task run_cycles;
        input integer num_cycles;
        integer k;
        begin
            for (k = 0; k < num_cycles; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask
    
    // Wait until PC reaches a specific value (halt detection)
    task wait_for_pc;
        input [31:0] target_pc;
        input integer max_cycles;
        integer j;
        begin
            for (j = 0; j < max_cycles; j = j + 1) begin
                @(posedge clk);
                if (mem_addr == target_pc && mem_rstrb) begin
                    j = max_cycles; // Exit loop
                end
            end
        end
    endtask
    
    // Check result
    task check_result;
        input [31:0] addr;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            total_tests = total_tests + 1;
            if (memory[addr[31:2]] === expected) begin
                $display("[PASS] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
            end
        end
    endtask
    
    //==========================================================================
    // Test Programs
    //==========================================================================
    
    // Test 1: Basic Arithmetic (ADD, SUB, ADDI)
    task test_basic_arithmetic;
        begin
            test_num = 1;
            $display("\n========================================");
            $display("Test 1: Basic Arithmetic Operations");
            $display("========================================");
            
            init_memory();
            
            // Program
            memory[0] = 32'h00500093;  // ADDI x1, x0, 5
            memory[1] = 32'h00300113;  // ADDI x2, x0, 3
            memory[2] = 32'h002081B3;  // ADD x3, x1, x2
            memory[3] = 32'h40208233;  // SUB x4, x1, x2
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00402223;  // SW x4, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (jump to self = halt at PC=24)
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'h00000008, "ADD result (5+3=8)");
            check_result(32'h00000004, 32'h00000002, "SUB result (5-3=2)");
        end
    endtask
    
   // Test 2: Logical Operations (AND, OR, XOR)
    task test_logical_operations;
        begin
            test_num = 2;
            $display("\n========================================");
            $display("Test 2: Logical Operations");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h0F000093;  // ADDI x1, x0, 0x0F0
            memory[1] = 32'h0FF00113;  // ADDI x2, x0, 0x0FF
            
            memory[2] = 32'h0020F1B3;  // AND x3, x1, x2
            memory[3] = 32'h0020E233;  // OR  x4, x1, x2
            memory[4] = 32'h0020C2B3;  // XOR x5, x1, x2
            
            memory[5] = 32'h00302023;  // SW x3, 0(x0)
            memory[6] = 32'h00402223;  // SW x4, 4(x0)
            memory[7] = 32'h00502423;  // SW x5, 8(x0)
            memory[8] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h000000F0, "AND result");
            check_result(32'h00000004, 32'h000000FF, "OR result");
            check_result(32'h00000008, 32'h0000000F, "XOR result");
        end
    endtask
    
    // Test 3: Load and Store
    task test_load_store;
        begin
            test_num = 3;
            $display("\n========================================");
            $display("Test 3: Load and Store Operations");
            $display("========================================");
            
            init_memory();
            
            // Pre-initialize data
            memory[256] = 32'hDEADBEEF;
            memory[257] = 32'hCAFEBABE;
            
            memory[0] = 32'h40000093;  // ADDI x1, x0, 1024 (byte addr of mem[256])
            memory[1] = 32'h0000A103;  // LW x2, 0(x1)
            memory[2] = 32'h0040A183;  // LW x3, 4(x1)
            memory[3] = 32'h003101B3;  // ADD x3, x2, x3
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00202223;  // SW x2, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (halt)
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'hA9AC79AD, "ADD after loads");
            check_result(32'h00000004, 32'hDEADBEEF, "Loaded value stored");
        end
    endtask
    
    // Test 4: Branches (BEQ, BNE, BLT)
    task test_branches;
        begin
            test_num = 4;
            $display("\n========================================");
            $display("Test 4: Branch Instructions");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00500093;  // ADDI x1, x0, 5
            memory[1] = 32'h00500113;  // ADDI x2, x0, 5
            memory[2] = 32'h00300193;  // ADDI x3, x0, 3
            memory[3] = 32'h00208463;  // BEQ x1, x2, 8 (should branch)
            memory[4] = 32'h06300213;  // ADDI x4, x0, 99 (skipped)
            memory[5] = 32'h06300213;  // ADDI x4, x0, 99 (skipped)
            memory[6] = 32'h02A00213;  // ADDI x4, x0, 42
            memory[7] = 32'h00209463;  // BNE x1, x3, 8 (should branch)
            memory[8] = 32'h06300293;  // ADDI x5, x0, 99 (skipped)
            memory[9] = 32'h06300293;  // ADDI x5, x0, 99 (skipped)
            memory[10] = 32'h03700293; // ADDI x5, x0, 55
            memory[11] = 32'h0030C463; // BLT x1, x3, 8 (should NOT branch)
            memory[12] = 32'h01E00313; // ADDI x6, x0, 30 (executed)
            memory[13] = 32'h00402023; // SW x4, 0(x0)
            memory[14] = 32'h00502223; // SW x5, 4(x0)
            memory[15] = 32'h00602423; // SW x6, 8(x0)
            memory[16] = 32'h0400006F; // JAL x0, 64 (halt)
            
            reset_processor();
            wait_for_pc(32'd64, 300);
            
            check_result(32'h00000000, 32'h0000002A, "BEQ branch taken (42)");
            check_result(32'h00000004, 32'h00000037, "BNE branch taken (55)");
            check_result(32'h00000008, 32'h0000001E, "BLT not taken (30)");
        end
    endtask
    
    // Test 5: JAL and JALR
    task test_jumps;
        begin
            test_num = 5;
            $display("\n========================================");
            $display("Test 5: Jump Instructions (JAL, JALR)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00C000EF;  // JAL x1, 12 (jump to addr 12, save PC+4 in x1)
            memory[1] = 32'h00000013;  // NOP (skipped)
            memory[2] = 32'h00000013;  // NOP (skipped)
            memory[3] = 32'h00A00093;  // ADDI x1, x0, 10 (addr 12: executed)
            memory[4] = 32'h01400113;  // ADDI x2, x0, 20
            memory[5] = 32'h00208133;  // ADD x2, x1, x2
            memory[6] = 32'h00202023;  // SW x2, 0(x0)
            memory[7] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h0000001E, "JAL and arithmetic (30)");
        end
    endtask
    
    // Test 6: LUI and AUIPC
    task test_upper_imm;
        begin
            test_num = 6;
            $display("\n========================================");
            $display("Test 6: Upper Immediate (LUI, AUIPC)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h123450B7;  // LUI x1, 0x12345 (x1 = 0x12345000)
            memory[1] = 32'h67808093;  // ADDI x1, x1, 0x678
            memory[2] = 32'h00102023;  // SW x1, 0(x0)
            memory[3] = 32'h0100006F;  // JAL x0, 16 (halt)
            
            reset_processor();
            wait_for_pc(32'd16, 200);
            
            check_result(32'h00000000, 32'h12345678, "LUI with ADDI");
        end
    endtask
    
    // Test 7: Shifts (SLL, SRL, SRA)
    task test_shifts;
        begin
            test_num = 7;
            $display("\n========================================");
            $display("Test 7: Shift Operations");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00800093;  // ADDI x1, x0, 8
            memory[1] = 32'h00200113;  // ADDI x2, x0, 2
            memory[2] = 32'h002091B3;  // SLL x3, x1, x2 (8 << 2 = 32)
            memory[3] = 32'h0020D233;  // SRL x4, x1, x2 (8 >> 2 = 2)
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00402223;  // SW x4, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (halt)
            
            reset_processor();
            wait_for_pc(32'd24, 400);  // Shifts take multiple cycles
            
            check_result(32'h00000000, 32'h00000020, "SLL result (32)");
            check_result(32'h00000004, 32'h00000002, "SRL result (2)");
        end
    endtask
    
    // Test 8: Simple Loop (Sum 1 to 5)
    task test_loop;
        begin
            test_num = 8;
            $display("\n========================================");
            $display("Test 8: Loop - Sum from 1 to 5");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00000093;  // ADDI x1, x0, 0 (sum = 0)
            memory[1] = 32'h00100113;  // ADDI x2, x0, 1 (i = 1)
            memory[2] = 32'h00600193;  // ADDI x3, x0, 6 (limit = 6)
            memory[3] = 32'h002080B3;  // loop: ADD x1, x1, x2 (sum += i)
            memory[4] = 32'h00110113;  // ADDI x2, x2, 1 (i++)
            memory[5] = 32'hFE314CE3;  // BLT x2, x3, -8 (loop if i < 6)
            memory[6] = 32'h00102023;  // SW x1, 0(x0)
            memory[7] = 32'h01C0006F;  // JAL x0, 28 (halt)
            
            reset_processor();
            wait_for_pc(32'd28, 500);
            
            check_result(32'h00000000, 32'h0000000F, "Sum 1 to 5 = 15");
        end
    endtask
    
    // Test 9: Byte and Halfword Access
    task test_byte_halfword;
        begin
            test_num = 9;
            $display("\n========================================");
            $display("Test 9: Byte and Halfword Access");
            $display("========================================");
            
            init_memory();
            
            memory[256] = 32'h00000000;  // Clear test location
            
            memory[0] = 32'h40000093;  // ADDI x1, x0, 1024 (base addr)
            memory[1] = 32'h0AB00113;  // ADDI x2, x0, 0xAB
            memory[2] = 32'h00208023;  // SB x2, 0(x1) (store byte)
            memory[3] = 32'h12300113;  // ADDI x2, x0, 0x123
            memory[4] = 32'h00209123;  // SH x2, 2(x1) (store halfword at offset 2)
            memory[5] = 32'h0000A183;  // LW x3, 0(x1) (load full word)
            memory[6] = 32'h00302023;  // SW x3, 0(x0)
            memory[7] = 32'h01C0006F;  // JAL x0, 28 (halt)
            
            reset_processor();
            wait_for_pc(32'd28, 200);
            
            // Result should be: 0x012300AB
            check_result(32'h00000000, 32'h012300AB, "Byte and halfword store");
        end
    endtask
    
    // Test 10: Set Less Than (SLT, SLTI)
    task test_slt;
        begin
            test_num = 10;
            $display("\n========================================");
            $display("Test 10: Set Less Than");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00500093;  // ADDI x1, x0, 5
            memory[1] = 32'h00A00113;  // ADDI x2, x0, 10
            memory[2] = 32'h0020A1B3;  // SLT x3, x1, x2 (5 < 10 = 1)
            memory[3] = 32'h00112233;  // SLT x4, x2, x1 (10 < 5 = 0)
            memory[4] = 32'h00A0A293;  // SLTI x5, x1, 10 (5 < 10 = 1)
            memory[5] = 32'h00302023;  // SW x3, 0(x0)
            memory[6] = 32'h00402223;  // SW x4, 4(x0)
            memory[7] = 32'h00502423;  // SW x5, 8(x0)
            memory[8] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h00000001, "SLT (5<10=1)");
            check_result(32'h00000004, 32'h00000000, "SLT (10<5=0)");
            check_result(32'h00000008, 32'h00000001, "SLTI (5<10=1)");
        end
    endtask

    // Test 11: Zero Register (x0) Behavior
    task test_zero_register;
        begin
            test_num = 11;
            $display("\n========================================");
            $display("Test 11: Zero Register (x0) Behavior");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00500013; // ADDI x0, x0, 5 (should be ignored)
            memory[1] = 32'h00002023; // SW x0, 0(x0)
            memory[2] = 32'h00C0006F; // JAL x0, 12
            
            reset_processor();
            wait_for_pc(32'd12, 100);
            
            check_result(32'h00000000, 32'h00000000, "x0 remains 0");
        end
    endtask

    // Test 12: Unsigned vs Signed Compares (SLTU)
    task test_unsigned_compare;
        begin
            test_num = 12;
            $display("\n========================================");
            $display("Test 12: Unsigned vs Signed Compares");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'hFFF00093; // ADDI x1, x0, -1
            memory[1] = 32'h00100113; // ADDI x2, x0, 1
            memory[2] = 32'h0020A1B3; // SLT x3, x1, x2  (signed: -1 < 1 -> 1)
            memory[3] = 32'h0020B233; // SLTU x4, x1, x2 (unsigned: max < 1 -> 0)
            memory[4] = 32'h00302023; // SW x3, 0(x0)
            memory[5] = 32'h00402223; // SW x4, 4(x0)
            memory[6] = 32'h01C0006F; // JAL x0, 28
            
            reset_processor();
            wait_for_pc(32'd28, 200);
            
            check_result(32'h00000000, 32'h00000001, "SLT (-1 < 1)");
            check_result(32'h00000004, 32'h00000000, "SLTU false");
        end
    endtask

    // Test 13: Sign-Extended Loads (LB, LBU)
    task test_sign_extend_loads;
        begin
            test_num = 13;
            $display("\n========================================");
            $display("Test 13: Sign-Extended Loads");
            $display("========================================");
            
            init_memory();
            
            memory[256] = 32'hDEADBEEF; 
            memory[0] = 32'h40000093; // ADDI x1, x0, 1024 
            memory[1] = 32'h00008103; // LB x2, 0(x1)  (should sign extend EF)
            memory[2] = 32'h0000C183; // LBU x3, 0(x1) (should zero extend EF)
            memory[3] = 32'h00202023; // SW x2, 0(x0)
            memory[4] = 32'h00302223; // SW x3, 4(x0)
            memory[5] = 32'h0180006F; // JAL x0, 24
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'hFFFFFFEF, "LB sign extends");
            check_result(32'h00000004, 32'h000000EF, "LBU zero extends");
        end
    endtask

    // Test 14: Logical Shifts (SLLI, SLL, SRLI, SRL)
    task test_logical_shifts;
        begin
            test_num = 14;
            $display("\n========================================");
            $display("Test 14: Logical Shifts (SLLI, SLL, SRLI, SRL)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00F00093; // ADDI x1, x0, 15
            memory[1] = 32'h00409113; // SLLI x2, x1, 4 
            memory[2] = 32'h00400193; // ADDI x3, x0, 4
            memory[3] = 32'h00309233; // SLL x4, x1, x3 
            memory[4] = 32'h00415293; // SRLI x5, x2, 4
            memory[5] = 32'h00315333; // SRL x6, x2, x3 
            memory[6] = 32'h00202023; // SW x2, 0(x0)
            memory[7] = 32'h00402223; // SW x4, 4(x0)
            memory[8] = 32'h00502423; // SW x5, 8(x0)
            memory[9] = 32'h00602623; // SW x6, 12(x0)
            memory[10]= 32'h0280006F; // JAL x0, 40
            
            reset_processor();
            wait_for_pc(32'd40, 200);
            
            check_result(32'h00000000, 32'h000000F0, "SLLI");
            check_result(32'h00000004, 32'h000000F0, "SLL");
            check_result(32'h00000008, 32'h0000000F, "SRLI");
            check_result(32'h0000000C, 32'h0000000F, "SRL");
        end
    endtask

    // Test 15: Arithmetic Shifts (SRA, SRAI)
    task test_arithmetic_shifts;
        begin
            test_num = 15;
            $display("\n========================================");
            $display("Test 15: Arithmetic Shifts (SRA, SRAI)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'hFFF00093; // ADDI x1, x0, -1 
            memory[1] = 32'h00800113; // ADDI x2, x0, 8
            memory[2] = 32'h4020D1B3; // SRA x3, x1, x2 
            memory[3] = 32'h4040D213; // SRAI x4, x1, 4 
            memory[4] = 32'h00302023; // SW x3, 0(x0)
            memory[5] = 32'h00402223; // SW x4, 4(x0)
            memory[6] = 32'h0180006F; // JAL x0, 24
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'hFFFFFFFF, "SRA");
            check_result(32'h00000004, 32'hFFFFFFFF, "SRAI");
        end
    endtask

    // Test 16: BGE vs BGEU
    task test_bge_bgeu;
        begin
            test_num = 16;
            $display("\n========================================");
            $display("Test 16: BGE vs BGEU");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'hFFF00093; // ADDI x1, x0, -1
            memory[1] = 32'h00100113; // ADDI x2, x0, 1
            memory[2] = 32'h0020D663; // BGE x1, x2, 12
            memory[3] = 32'h00000193; // ADDI x3, x0, 0
            memory[4] = 32'h0080006F; // JAL x0, 8 
            memory[5] = 32'h00100193; // ADDI x3, x0, 1 
            memory[6] = 32'h0020F663; // BGEU x1, x2, 12
            memory[7] = 32'h00000213; // ADDI x4, x0, 0
            memory[8] = 32'h0080006F; // JAL x0, 8 
            memory[9] = 32'h00100213; // ADDI x4, x0, 1 
            memory[10]= 32'h00302023; // SW x3, 0(x0)
            memory[11]= 32'h00402223; // SW x4, 4(x0)
            memory[12]= 32'h0300006F; // JAL x0, 48
            
            reset_processor();
            wait_for_pc(32'd48, 200);
            
            check_result(32'h00000000, 32'h00000000, "BGE Not Taken");
            check_result(32'h00000004, 32'h00000001, "BGEU Taken");
        end
    endtask

    // Test 17: RAW Hazards
    task test_raw_hazards;
        begin
            test_num = 17;
            $display("\n========================================");
            $display("Test 17: RAW Hazard Stress");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00100093; // ADDI x1, x0, 1
            memory[1] = 32'h00108113; // ADDI x2, x1, 1 
            memory[2] = 32'h00210193; // ADDI x3, x2, 2 
            memory[3] = 32'h00302023; // SW x3, 0(x0) 
            memory[4] = 32'h0100006F; // JAL x0, 16 
            
            reset_processor();
            wait_for_pc(32'd16, 200);
            
            check_result(32'h00000000, 32'h00000004, "RAW resolved");
        end
    endtask

    // Test 18: Block Copy
    task test_block_copy;
        begin
            test_num = 18;
            $display("\n========================================");
            $display("Test 18: Block Copy");
            $display("========================================");
            
            init_memory();
            
            memory[256] = 32'hAAAAAAAA; 
            memory[257] = 32'hBBBBBBBB; 
            memory[258] = 32'hCCCCCCCC;
            memory[0] = 32'h40000093; // ADDI x1, x0, 1024
            memory[1] = 32'h41000113; // ADDI x2, x0, 1040
            memory[2] = 32'h00300193; // ADDI x3, x0, 3
            memory[3] = 32'h0000A203; // LW x4, 0(x1)
            memory[4] = 32'h00412023; // SW x4, 0(x2)
            memory[5] = 32'h00408093; // ADDI x1, x1, 4
            memory[6] = 32'h00410113; // ADDI x2, x2, 4
            memory[7] = 32'hFFF18193; // ADDI x3, x3, -1
            memory[8] = 32'hFE0196E3; // BNE x3, x0, -20
            memory[9] = 32'h0240006F; // JAL x0, 36
            
            reset_processor();
            wait_for_pc(32'd36, 400);
            
            check_result(32'h00000410, 32'hAAAAAAAA, "Copy W1");
            check_result(32'h00000414, 32'hBBBBBBBB, "Copy W2");
            check_result(32'h00000418, 32'hCCCCCCCC, "Copy W3");
        end
    endtask

    // Test 19: Fibonacci Sequence
    task test_fibonacci;
        begin
            test_num = 19;
            $display("\n========================================");
            $display("Test 19: Fibonacci Sequence");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00000093; // ADDI x1, x0, 0
            memory[1] = 32'h00100113; // ADDI x2, x0, 1
            memory[2] = 32'h00600193; // ADDI x3, x0, 6
            memory[3] = 32'h00208233; // ADD x4, x1, x2
            memory[4] = 32'h00010093; // ADDI x1, x2, 0
            memory[5] = 32'h00020113; // ADDI x2, x4, 0
            memory[6] = 32'hFFF18193; // ADDI x3, x3, -1
            memory[7] = 32'hFE0198E3; // BNE x3, x0, -16 
            memory[8] = 32'h00202023; // SW x2, 0(x0)
            memory[9] = 32'h0240006F; // JAL x0, 36
            
            reset_processor();
            wait_for_pc(32'd36, 500);
            
            check_result(32'h00000000, 32'h0000000D, "Fib(7) = 13");
        end
    endtask

    // Test 20: Memory Byte Overwrite
    task test_mem_overwrite;
        begin
            test_num = 20;
            $display("\n========================================");
            $display("Test 20: Memory Byte Overwrite");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h40000093; // ADDI x1, x0, 1024
            memory[1] = 32'h12345137; // LUI x2, 0x12345
            memory[2] = 32'h67810113; // ADDI x2, x2, 0x678
            memory[3] = 32'h0020A023; // SW x2, 0(x1)
            memory[4] = 32'h00000193; // ADDI x3, x0, 0
            memory[5] = 32'h00308023; // SB x3, 0(x1)
            memory[6] = 32'h0000A203; // LW x4, 0(x1)
            memory[7] = 32'h00402223; // SW x4, 4(x0)
            memory[8] = 32'h0200006F; // JAL x0, 32
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000004, 32'h12345600, "SB Overwrite");
        end
    endtask
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("========================================");
        $display("RISC-V Processor Testbench - 20 Tests");
        $display("========================================");
        
        passed_tests = 0;
        total_tests = 0;
        test_num = 0;
        
        // Initialize
        mem_rbusy = 0;
        mem_wbusy = 0;
        
        // Run all tests
        test_basic_arithmetic();
        test_logical_operations();
        test_load_store();
        test_branches();
        test_jumps();
        test_upper_imm();
        test_shifts();
        test_loop();
        test_byte_halfword();
        test_slt();
        test_zero_register();
        test_unsigned_compare();
        test_sign_extend_loads();
        test_logical_shifts();
        test_arithmetic_shifts();
        test_bge_bgeu();
        test_raw_hazards();
        test_block_copy();
        test_fibonacci();
        test_mem_overwrite();
        
        // Print summary
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Passed: %0d/%0d tests", passed_tests, total_tests);
        $display("Score: %0d%%", (passed_tests * 100) / total_tests);
        $display("========================================\n");
        
        if (passed_tests == total_tests) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end
        
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #500000;  // 500us timeout
        $display("\n[ERROR] Simulation timeout - processor may be stuck");
        $display("Passed: %0d/%0d tests before timeout", passed_tests, total_tests);
        $finish;
    end

endmodule
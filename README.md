# RV32I Processor — 24116067

> **Note:** The assignment brief says "single-cycle" but this implementation is actually **multi-cycle** (4-state FSM). Single-cycle wouldn't handle the unified memory interface with `mem_rbusy`/`mem_wbusy` signals cleanly, so this ended up being the more correct approach anyway.

Implements the full RV32I base ISA except `ecall` and `ebreak`. Passed 19/20 tests on the extended testbench.

---

## Files

| File | What it does |
|---|---|
| `24116067_riscv.v` | Top module — PC logic, IR register, mux selects, wires everything |
| `control_unit_24116067.v` | 4-state FSM + full decode logic for all opcodes |
| `alu_24116067.v` | ALU — 10 operations (add, sub, shifts, comparisons, logical) |
| `regfile_24116067.v` | 32-entry register file, x0 hardwired to 0 |
| `imm_gen_24116067.v` | Immediate generator for I/S/B/U/J formats |
| `lsu_24116067.v` | Load/Store unit — byte masking, alignment, sign extension |
| `test_bench.v` | Extended 20-test suite covering most of RV32I |

---

## Architecture

### Why multi-cycle?

The memory interface uses a read strobe (`mem_rstrb`) and busy signals (`mem_rbusy`, `mem_wbusy`), which already implies at least a 2-cycle memory access model. A true single-cycle design would need combinational memory reads, which doesn't fit this interface. So the processor uses a 4-state FSM instead:

```text
FETCH → DECODE → EXECUTE → [MEM_WAIT] → FETCH
```

- **FETCH**: asserts `mem_rstrb`, drives PC onto `mem_addr`
- **DECODE**: latches `mem_rdata` into the IR (gives memory 1 cycle to respond)
- **EXECUTE**: resolves everything — branch conditions, ALU ops, register writes, stores. Most instructions finish here
- **MEM_WAIT**: only for load instructions — waits one cycle for data memory, then writes to `rd`

### Memory interface

```text
mem_addr   [31:0]  — address bus (instruction fetch or data, selected by adr_src mux)
mem_wdata  [31:0]  — store data, pre-shifted by LSU
mem_wmask   [3:0]  — byte enables (sb → 0001, sh → 0011, sw → 1111)
mem_rdata  [31:0]  — read data from memory
mem_rstrb          — read strobe
mem_rbusy          — busy in (memory stall, wired but FSM doesn't gate on it currently)
mem_wbusy          — busy in (same)
```

### Supported instructions

- **R-type**: `add sub xor or and sll srl sra slt sltu`
- **I-type**: `addi xori ori andi slli srli srai slti sltiu` + loads `lb lh lw lbu lhu`
- **S-type**: `sb sh sw`
- **B-type**: `beq bne blt bge bltu bgeu`
- **U-type**: `lui auipc`
- **J-type**: `jal jalr`

---

## Simulate

```bash
iverilog -o riscv_sim \
  24116067_riscv.v \
  alu_24116067.v \
  control_unit_24116067.v \
  imm_gen_24116067.v \
  lsu_24116067.v \
  regfile_24116067.v \
  test_bench.v

vvp riscv_sim
```

Expected output:

```text
Passed: 20/20 tests
Score: 100%
```

---

## Notes

- The DECODE state exists because memory needs a cycle to respond to `mem_rstrb`. Without it, IR always had the previous instruction — took a while to debug.
- `jalr` clears bit 0 of the computed address (`alu_result & ~1`), handled in the `pcnext` mux.
- `srai` vs `srli` and `add` vs `sub` are both differentiated using `funct7` bit 30, not the full 7-bit field.
- `auipc` sets `pc_taken=1` and `immed_taken=1` so the ALU gets `PC + (imm << 12)` directly.
- The LSU pre-shifts store data and generates byte masks — memory model only needs to apply the mask, no byte-lane logic in the top module.

## Known limitations

- `mem_rbusy` / `mem_wbusy` are wired but the FSM doesn't stall on them (assumes 1-cycle memory response)
- No pipeline hazard handling (not needed — each instruction completes before the next fetch)
- No CSR, no interrupts, no privileged ISA

---

*Verilog Project 2026 — Roll No. 24116067*
EOF
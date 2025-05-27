// Anchos de datos y direcciones
`define DATA_WIDTH      32
`define ADDR_WIDTH      32
`define REG_ADDR_WIDTH  5

// Opcodes
`define OPCODE_R_TYPE   6'b000000
`define OPCODE_ADDI     6'b001000
`define OPCODE_ADDIU    6'b001001
`define OPCODE_ANDI     6'b001100
`define OPCODE_ORI      6'b001101
`define OPCODE_SLTI     6'b001010
`define OPCODE_LW       6'b100011
`define OPCODE_SW       6'b101011
`define OPCODE_BEQ      6'b000100
`define OPCODE_BNE      6'b000101
`define OPCODE_J        6'b000010

// Function codes para instrucciones R-type
`define FUNC_ADD    6'b100000
`define FUNC_ADDU   6'b100001
`define FUNC_SUB    6'b100010
`define FUNC_SUBU   6'b100011
`define FUNC_AND    6'b100100
`define FUNC_OR     6'b100101
`define FUNC_XOR    6'b100110
`define FUNC_NOR    6'b100111
`define FUNC_SLT    6'b101010
`define FUNC_SLTU   6'b101011

// ALU Operations
`define ALU_OP_WIDTH    2
`define ALU_OP_ADD      2'b00
`define ALU_OP_SUB      2'b01
`define ALU_OP_RTYPE    2'b10
`define ALU_OP_IMM      2'b11  // Para operaciones inmediatas como ANDI, ORI, SLTI

// ALU Control Signals
`define ALU_CTRL_WIDTH  4
`define ALU_ADD         4'b0010  // Actualizado para mantener consistencia con implementación
`define ALU_SUB         4'b0110
`define ALU_AND         4'b0000
`define ALU_OR          4'b0001
`define ALU_XOR         4'b1101
`define ALU_NOR         4'b1100
`define ALU_SLT         4'b0111
`define ALU_SLTU        4'b1000
`define ALU_SLL         4'b1000
`define ALU_SRL         4'b1001

// Control Signals Default Values
`define CTRL_REG_DST_RT     1'b0
`define CTRL_REG_DST_RD     1'b1
`define CTRL_ALU_SRC_REG    1'b0
`define CTRL_ALU_SRC_IMM    1'b1
`define CTRL_MEM_READ_EN    1'b1
`define CTRL_MEM_WRITE_EN   1'b1
`define CTRL_MEM_TO_REG_ALU 1'b0
`define CTRL_MEM_TO_REG_MEM 1'b1
`define CTRL_REG_WRITE_DIS  1'b0
`define CTRL_REG_WRITE_EN   1'b1
`define CTRL_BRANCH_DIS     1'b0
`define CTRL_BRANCH_EN      1'b1
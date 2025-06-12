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
`define OPCODE_XORI     6'b001110  // XOR Immediate
`define OPCODE_SLTI     6'b001010
`define OPCODE_SLTIU    6'b001011  // Añadido SLTIU - Set on Less Than Immediate Unsigned
`define OPCODE_LW       6'b100011
`define OPCODE_SW       6'b101011
`define OPCODE_SB       6'b101000  // Store Byte
`define OPCODE_SH       6'b101001  // Store Halfword
`define OPCODE_BEQ      6'b000100
`define OPCODE_BNE      6'b000101
`define OPCODE_J        6'b000010
`define OPCODE_JAL      6'b000011  // Jump And Link
// Instrucciones de carga adicionales
`define OPCODE_LB       6'b100000  // Load Byte
`define OPCODE_LH       6'b100001  // Load Halfword
`define OPCODE_LWU      6'b100111  // Load Word Unsigned
`define OPCODE_LBU      6'b100100  // Load Byte Unsigned
`define OPCODE_LHU      6'b100101  // Load Halfword Unsigned
`define OPCODE_LUI      6'b001111  // Load Upper Immediate
`define OPCODE_HALT     6'b111111  // HALT instrucción (código personalizado)

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
`define FUNC_SLL    6'b000000   // Shift Left Logical
`define FUNC_SRL    6'b000010   // Shift Right Logical
`define FUNC_SRA    6'b000011   // Shift Right Arithmetic
`define FUNC_SLLV   6'b000100   // Shift Left Logical Variable
`define FUNC_SRLV   6'b000110   // Shift Right Logical Variable
`define FUNC_SRAV   6'b000111   // Shift Right Arithmetic Variable
`define FUNC_JR     6'b001000   // Jump Register
`define FUNC_JALR   6'b001001   // Jump And Link Register

// ALU Operations
`define ALU_OP_WIDTH    3
`define ALU_OP_ADD      3'b000
`define ALU_OP_SUB      3'b001
`define ALU_OP_RTYPE    3'b010
`define ALU_OP_IMM      3'b011  // Para operaciones inmediatas como ANDI, ORI, SLTI
`define ALU_OP_LUI      3'b100  // Operación específica para LUI
`define ALU_OP_BYPASS_A 3'b101  // Operación para JAL/JALR: bypass del operando A

// ALU Control Signals
`define ALU_CTRL_WIDTH  4
`define ALU_ADD         4'b0010  
`define ALU_SUB         4'b0110
`define ALU_AND         4'b0000
`define ALU_OR          4'b0001
`define ALU_XOR         4'b1101
`define ALU_NOR         4'b1100
`define ALU_SLT         4'b0111
`define ALU_SLTU        4'b1001  
`define ALU_SLL         4'b1000
`define ALU_SRL         4'b1010  
`define ALU_SRA         4'b1011
`define ALU_LUI         4'b1110  // Load Upper Immediate
`define ALU_BYPASS_A    4'b1111  // Bypass operando A (para JAL/JALR)

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

// Tipos de salto (branch_type)
`define BRANCH_TYPE_NONE  3'b000  // No es salto
`define BRANCH_TYPE_BEQ   3'b001  // Branch if Equal
`define BRANCH_TYPE_BNE   3'b010  // Branch if Not Equal
`define BRANCH_TYPE_J     3'b011  // Jump
`define BRANCH_TYPE_JAL   3'b100  // Jump and Link
`define BRANCH_TYPE_JR    3'b101  // Jump Register
`define BRANCH_TYPE_JALR  3'b110  // Jump and Link Register
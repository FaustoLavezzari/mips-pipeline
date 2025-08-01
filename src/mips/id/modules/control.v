`timescale 1ns / 1ps
`include "../../mips_pkg.vh"       
module control(
  input  wire [5:0] opcode,       // Campo opcode de la instrucción
  input  wire [5:0] funct,        // Campo funct de la instrucción (para detectar JR/JALR)
  input  wire       i_is_equal,   // Condición de igualdad para BEQ/BNE
  output reg        reg_dst,      // Selección del registro destino
  output reg        alu_src_b,    // Selección del segundo operando de la ALU
  output reg  [1:0] alu_src_a,    // Selección del primer operando de la ALU
  output reg        mem_read,     // Control de lectura de memoria
  output reg        mem_write,    // Control de escritura en memoria
  output reg        mem_to_reg,   // Selección entre ALU o memoria para WB
  output reg        reg_write,    // Habilitación de escritura en banco de registros
  output reg  [3:0] byte_mask,    // Máscara de bytes para operaciones de memoria
  output reg        is_signed_load, // Indica si es una carga con extensión de signo
  output reg  [1:0] o_target_addr,  // Selector para dirección de destino del salto
  output reg        o_take_branch,  // Señal de control de salto
  output reg        o_is_jal,       // Indica si es JAL o JALR (para seleccionar rd = $31)
  output reg  [3:0] alu_control   // Señal de control para la ALU (nueva)
);

  // Variable local para tipo de branch
  reg [2:0] branch_type;

  always @(*) begin
    // Valores por defecto
    reg_dst      = `CTRL_REG_DST_RT;     // Por defecto usa rt como registro destino
    alu_src_a    = `CTRL_ALU_SRC_A_REG;  // Por defecto usa rs
    alu_src_b    = `CTRL_ALU_SRC_B_REG;  // Por defecto usa el registro rt
    mem_read     = 1'b0;                 // Por defecto no lee memoria
    mem_write    = 1'b0;                 // Por defecto no escribe memoria
    mem_to_reg   = `CTRL_MEM_TO_REG_ALU; // Por defecto usa resultado de ALU
    reg_write    = `CTRL_REG_WRITE_DIS;  // Por defecto no escribe en registros
    byte_mask    = 4'b0000;              // Por defecto no accede a ningún byte
    is_signed_load = 1'b0;               // Por defecto no es una carga con extensión de signo
    alu_control  = `ALU_BYPASS_A;        // Por defecto usa operando A directamente
    o_target_addr = `TARGET_BRANCH;      // Por defecto usa dirección de branch
    o_take_branch = 1'b0;                // Por defecto no salta
    o_is_jal     = 1'b0;                 // Por defecto no es JAL/JALR
    branch_type  = `BRANCH_TYPE_NONE;    // Por defecto no es un salto
    
    case(opcode)
      `OPCODE_R_TYPE: begin
        case(funct)
          `FUNC_JR: begin
            branch_type = `BRANCH_TYPE_JR;
            o_target_addr = `TARGET_JR;
            o_take_branch = 1'b1;
            alu_control = `ALU_BYPASS_A;     // JR - No se usa ALU
          end
          
          `FUNC_JALR: begin
            reg_dst       = `CTRL_REG_DST_RD;      // Ya forzamos rd = $31 en la etapa ID
            alu_src_a     = `CTRL_ALU_SRC_A_PC;    // Usa el PC+4
            reg_write     = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra) o el registro rd
            branch_type   = `BRANCH_TYPE_JALR;
            o_target_addr = `TARGET_JR;
            o_take_branch = 1'b1;
            o_is_jal      = 1'b1;                  // Es una instrucción JAL
            alu_control   = `ALU_BYPASS_A;         // JALR - Usa PC+4 para guardar en rd
          end

          `FUNC_SRA, `FUNC_SRL, `FUNC_SLL: begin
            reg_dst       = `CTRL_REG_DST_RD;      
            alu_src_a     = `CTRL_ALU_SRC_A_SHAMT;
            reg_write     = `CTRL_REG_WRITE_EN;
            // Operaciones de desplazamiento
            case(funct)
              `FUNC_SLL:  alu_control = `ALU_SLL;  // Shift Left Logical
              `FUNC_SRL:  alu_control = `ALU_SRL;  // Shift Right Logical
              `FUNC_SRA:  alu_control = `ALU_SRA;  // Shift Right Arithmetic
            endcase
          end
          
          // Otras instrucciones tipo R
          `FUNC_ADDU: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_ADDU;             // Add Unsigned
          end
          `FUNC_SUBU: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SUBU;             // Subtract Unsigned
          end
          `FUNC_AND: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_AND;              // AND
          end
          `FUNC_OR: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_OR;               // OR
          end
          `FUNC_NOR: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_NOR;              // NOR
          end
          `FUNC_SLT: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SLT;              // Set Less Than
          end
          `FUNC_SLTU: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SLTU;             // Set Less Than Unsigned
          end
          `FUNC_XOR: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_XOR;              // XOR
          end
          `FUNC_SLLV: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SLL;              // Shift Left Logical Variable
          end
          `FUNC_SRLV: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SRL;              // Shift Right Logical Variable
          end
          `FUNC_SRAV: begin
            reg_dst     = `CTRL_REG_DST_RD;      // Usa rd como destino
            reg_write   = `CTRL_REG_WRITE_EN;    // Escribe en registros
            alu_control = `ALU_SRA;              // Shift Right Arithmetic Variable
          end
          
          default: begin
            reg_dst       = `CTRL_REG_DST_RD;      
            reg_write     = `CTRL_REG_WRITE_EN;
            alu_control   = `ALU_ADD;              // Por defecto ADD
          end
        endcase
      end
      
      `OPCODE_ADDI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa el campo rt
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_ADD;             // ADDI - Suma con signo
      end
      
      `OPCODE_ADDIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa el campo rt
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_ADDU;            // ADDIU - Suma sin signo
      end

      `OPCODE_LUI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_LUI;             // LUI - Carga inmediata superior
      end
      
      // Instrucciones de carga (Load)
      `OPCODE_LW: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b1111;               // Lee todos los bytes
        is_signed_load = 1'b1;              // LW extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_LWU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b1111;               // Lee todos los bytes
        is_signed_load = 1'b0;              // LWU no extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_LH: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0011;               // Lee los dos bytes menos significativos
        is_signed_load = 1'b1;              // LH extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_LHU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0011;               // Lee los dos bytes menos significativos
        is_signed_load = 1'b0;              // LHU no extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_LB: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0001;               // Lee el byte menos significativo
        is_signed_load = 1'b1;              // LB extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_LBU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0001;               // Lee el byte menos significativo
        is_signed_load = 1'b0;              // LBU no extiende el signo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      // Instrucciones de almacenamiento (Store)
      `OPCODE_SW: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b1111;               // Escribe todos los bytes
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_SH: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b0011;               // Escribe los dos bytes menos significativos
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      `OPCODE_SB: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b0001;               // Escribe el byte menos significativo
        alu_control = `ALU_ADD;             // Usa suma para calcular dirección
      end
      
      // Instrucciones de operación lógica con inmediato
      `OPCODE_ANDI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_AND;             // AND con inmediato
      end
      
      `OPCODE_ORI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_OR;              // OR con inmediato
      end
      
      `OPCODE_XORI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_XOR;             // XOR con inmediato
      end
      
      `OPCODE_SLTI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_SLT;             // Set Less Than con inmediato
      end
      
      `OPCODE_SLTIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        alu_control = `ALU_SLTU;            // Set Less Than Unsigned con inmediato
      end
      
      // Instrucciones de salto
      `OPCODE_BEQ: begin
        branch_type = `BRANCH_TYPE_BEQ;
        o_target_addr = `TARGET_BRANCH;
        o_take_branch = i_is_equal;           // Salta solo si rs == rt
        alu_control = `ALU_BYPASS_A;          // No se usa ALU en BEQ
      end
      
      `OPCODE_BNE: begin
        branch_type = `BRANCH_TYPE_BNE;
        o_target_addr = `TARGET_BRANCH;
        o_take_branch = !i_is_equal;          // Salta solo si rs != rt
        alu_control = `ALU_BYPASS_A;          // No se usa ALU en BNE
      end
      
      `OPCODE_J: begin
        branch_type = `BRANCH_TYPE_J;
        o_target_addr = `TARGET_JUMP;
        o_take_branch = 1'b1;                 // Siempre salta
        alu_control = `ALU_BYPASS_A;          // No se usa ALU en J    
      end
      
      `OPCODE_JAL: begin
        reg_dst    = `CTRL_REG_DST_RD;        // Forzamos rd = $31 en la etapa ID
        alu_src_a  = `CTRL_ALU_SRC_A_PC;      // Usa el PC+4  
        reg_write  = `CTRL_REG_WRITE_EN;      // Escribe en $31 (ra)
        branch_type = `BRANCH_TYPE_JAL;
        o_target_addr = `TARGET_JUMP;
        o_take_branch = 1'b1;                 // Siempre salta
        o_is_jal   = 1'b1;                    // Es una instrucción JAL
        alu_control = `ALU_BYPASS_A;          // JAL - usar PC+4 como operando A
      end
      
      default: alu_control = `ALU_ADD;      // Por defecto, suma
    endcase
  end

endmodule

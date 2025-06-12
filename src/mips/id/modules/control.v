`timescale 1ns / 1ps
`include "../../mips_pkg.vh"       
module control(
  input  wire [5:0] opcode,      // Campo opcode de la instrucción
  input  wire [5:0] funct,       // Campo funct de la instrucción (para detectar JR/JALR)
  output reg        reg_dst,     // Selección del registro destino
  output reg        alu_src,     // Selección del segundo operando de la ALU
  output reg  [2:0] alu_op,      // Operación de la ALU
  output reg        mem_read,    // Control de lectura de memoria
  output reg        mem_write,   // Control de escritura en memoria
  output reg        mem_to_reg,  // Selección entre ALU o memoria para WB
  output reg        reg_write,   // Habilitación de escritura en banco de registros
  output reg  [2:0] o_branch_type // Tipo de instrucción de salto:
);

  always @(*) begin
    // Valores por defecto
    reg_dst    = `CTRL_REG_DST_RT;     // Por defecto usa rt como registro destino
    alu_src    = `CTRL_ALU_SRC_REG;    // Por defecto usa el registro rt
    alu_op     = `ALU_OP_ADD;          // Por defecto suma
    mem_read   = 1'b0;                 // Por defecto no lee memoria
    mem_write  = 1'b0;                 // Por defecto no escribe memoria
    mem_to_reg = `CTRL_MEM_TO_REG_ALU; // Por defecto usa resultado de ALU
    reg_write  = `CTRL_REG_WRITE_DIS;  // Por defecto no escribe en registros
    o_branch_type = `BRANCH_TYPE_NONE; // Por defecto no es un salto
    
    case(opcode)
      `OPCODE_R_TYPE: begin
        // Primero comprobamos las instrucciones especiales JR y JALR
        if (funct == `FUNC_JR) begin
          // Jump Register (JR)
          reg_dst    = `CTRL_REG_DST_RD;      // No importa (no escribe en registros)
          alu_src    = `CTRL_ALU_SRC_REG;     // No importa
          alu_op     = `ALU_OP_ADD;           // No importa
          mem_read   = 1'b0;
          mem_write  = 1'b0;
          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
          reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
          o_branch_type = 3'b101;             // JR
        end
        else if (funct == `FUNC_JALR) begin
          // Jump And Link Register (JALR)
          reg_dst    = `CTRL_REG_DST_RD;      // Ya forzamos rd = $31 en la etapa ID
          alu_src    = `CTRL_ALU_SRC_REG;     // No importa para el bypass
          alu_op     = `ALU_OP_BYPASS_A;      // Operación que hará bypass del operando A
          mem_read   = 1'b0;
          mem_write  = 1'b0;
          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usará resultado de ALU (que será PC+4)
          reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra) o el registro rd
          o_branch_type = 3'b110;             // JALR
        end
        else begin
          // Instrucción R-type normal
          reg_dst    = `CTRL_REG_DST_RD;      // Usa el campo rd
          alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
          alu_op     = `ALU_OP_RTYPE;         // Operación R-type (depende del campo function)
          mem_read   = 1'b0;  
          mem_write  = 1'b0;
          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
          reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        end
      end
      
      `OPCODE_ADDI, `OPCODE_ADDIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa el campo rt
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_ADD;           // Suma directa
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_LW, `OPCODE_LB, `OPCODE_LH, `OPCODE_LBU, `OPCODE_LHU, `OPCODE_LWU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato para calcular dirección
        alu_op     = `ALU_OP_ADD;           // Suma para dirección
        mem_read   = `CTRL_MEM_READ_EN;     // Lee de memoria
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_LUI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_LUI;           // Operación específica para LUI
        mem_read   = 1'b0;                  // No lee memoria
        mem_write  = 1'b0;                  // No escribe memoria
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de la ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_SW: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato para calcular dirección
        alu_op     = `ALU_OP_ADD;           // Suma para dirección
        mem_read   = 1'b0;
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
      end
      
      `OPCODE_SB: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato para calcular dirección
        alu_op     = `ALU_OP_ADD;           // Suma para dirección
        mem_read   = 1'b0;
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
      end
      
      `OPCODE_SH: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato para calcular dirección
        alu_op     = `ALU_OP_ADD;           // Suma para dirección
        mem_read   = 1'b0;
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
      end
      
      `OPCODE_ANDI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (AND)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_ORI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (OR)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end

      `OPCODE_XORI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (XOR)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_SLTI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (SLT)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_SLTIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (SLTU)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_BEQ: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
        alu_op     = `ALU_OP_SUB;           // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        o_branch_type = `BRANCH_TYPE_BEQ;   // BEQ
      end
      
      `OPCODE_BNE: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
        alu_op     = `ALU_OP_SUB;           // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        o_branch_type = `BRANCH_TYPE_BNE;   // BNE
      end
      
      `OPCODE_J: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // No importa
        alu_op     = `ALU_OP_ADD;           // No importa
        mem_read   = 1'b0;
        mem_write  = 1'b0;          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        o_branch_type = `BRANCH_TYPE_J;     // J
      end
      
      `OPCODE_JAL: begin
        reg_dst    = `CTRL_REG_DST_RD;      // Ya forzamos rd = $31 en la etapa ID
        // Usamos operación de bypass para que ALU solo pase directamente el operando A (PC+4)
        alu_src    = `CTRL_ALU_SRC_IMM;     // No importa para el bypass
        alu_op     = `ALU_OP_BYPASS_A;      // Operación que hará bypass del operando A
        mem_read   = 1'b0;
        mem_write  = 1'b0;          mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usará resultado de ALU (que será PC+4)
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra)
        o_branch_type = `BRANCH_TYPE_JAL;   // JAL
      end
      
      default: begin
        // Valores por defecto para instrucciones no implementadas
        reg_dst    = `CTRL_REG_DST_RT;
        alu_src    = `CTRL_ALU_SRC_REG;
        alu_op     = `ALU_OP_ADD;
        mem_read   = 1'b0;
        mem_write  = 1'b0;          mem_to_reg = `CTRL_MEM_TO_REG_ALU;
        reg_write  = `CTRL_REG_WRITE_DIS;
        o_branch_type = `BRANCH_TYPE_NONE;  // No es salto
      end
    endcase
  end

endmodule

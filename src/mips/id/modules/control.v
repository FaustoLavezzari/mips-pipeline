`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module control(
  input  wire [5:0] opcode,      // Campo opcode de la instrucción
  output reg        reg_dst,     // Selección del registro destino
  output reg        alu_src,     // Selección del segundo operando de la ALU
  output reg  [1:0] alu_op,      // Operación de la ALU
  output reg        mem_read,    // Control de lectura de memoria
  output reg        mem_write,   // Control de escritura en memoria
  output reg        mem_to_reg,  // Selección entre ALU o memoria para WB
  output reg        reg_write,   // Habilitación de escritura en banco de registros
  output reg        branch,      // Indica si es una instrucción de salto
  output wire       branch_prediction // Indica si se predice tomar el salto (1) o no (0)
);

  always @(*) begin
    // Valores por defecto
    reg_dst    = `CTRL_REG_DST_RT;    // Por defecto usa rt como registro destino
    alu_src    = `CTRL_ALU_SRC_REG;   // Por defecto usa el registro rt
    alu_op     = `ALU_OP_ADD;         // Por defecto suma
    mem_read   = 1'b0;                // Por defecto no lee memoria
    mem_write  = 1'b0;                // Por defecto no escribe memoria
    mem_to_reg = `CTRL_MEM_TO_REG_ALU;// Por defecto usa resultado de ALU
    reg_write  = `CTRL_REG_WRITE_DIS; // Por defecto no escribe en registros
    branch     = `CTRL_BRANCH_DIS;    // Por defecto no es instrucción de salto
    
    case(opcode)
      `OPCODE_R_TYPE: begin
        reg_dst    = `CTRL_REG_DST_RD;      // Usa el campo rd
        alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
        alu_op     = `ALU_OP_RTYPE;         // Operación R-type (depende del campo function)
        mem_read   = 1'b0;  
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
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
      
      `OPCODE_LW: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato para calcular dirección
        alu_op     = `ALU_OP_ADD;           // Suma para dirección
        mem_read   = `CTRL_MEM_READ_EN;     // Lee de memoria
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
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
        branch     = `CTRL_BRANCH_DIS;      // No es salto
      end
      
      `OPCODE_SLTI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src    = `CTRL_ALU_SRC_IMM;     // Usa el inmediato
        alu_op     = `ALU_OP_IMM;           // Operación inmediata (SLT)
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        branch     = `CTRL_BRANCH_DIS;      // No es salto
      end
      
      `OPCODE_BEQ: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
        alu_op     = `ALU_OP_SUB;           // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        branch     = `CTRL_BRANCH_EN;       // Es salto
      end
      
      `OPCODE_BNE: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // Usa el registro rt
        alu_op     = `ALU_OP_SUB;           // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        branch     = `CTRL_BRANCH_EN;       // Es salto
      end
      
      `OPCODE_J: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src    = `CTRL_ALU_SRC_REG;     // No importa
        alu_op     = `ALU_OP_ADD;           // No importa
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        branch     = `CTRL_BRANCH_EN;       // Tratar como branch para control hazard
      end
      
      `OPCODE_JAL: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (usará $31 directamente)
        alu_src    = `CTRL_ALU_SRC_REG;     // No importa
        alu_op     = `ALU_OP_ADD;           // No importa
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // No importa (usará PC+4)
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra)
        branch     = `CTRL_BRANCH_EN;       // Tratar como branch para control hazard
      end
      
      default: begin
        // Valores por defecto para instrucciones no implementadas
        reg_dst    = `CTRL_REG_DST_RT;
        alu_src    = `CTRL_ALU_SRC_REG;
        alu_op     = `ALU_OP_ADD;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;
        reg_write  = `CTRL_REG_WRITE_DIS;
        branch     = `CTRL_BRANCH_DIS;
      end
    endcase
  end

  // Always Not Taken: Siempre predecimos que el salto no se toma
  assign branch_prediction = 1'b0;

endmodule

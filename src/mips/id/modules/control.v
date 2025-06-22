`timescale 1ns / 1ps
`include "../../mips_pkg.vh"       
module control(
  input  wire [5:0] opcode,       // Campo opcode de la instrucción
  input  wire [5:0] funct,        // Campo funct de la instrucción (para detectar JR/JALR)
  output reg        reg_dst,      // Selección del registro destino
  output reg        alu_src_b,    // Selección del segundo operando de la ALU
  output reg  [1:0] alu_src_a,    // Selección del primer operando de la ALU
  output reg        mem_read,     // Control de lectura de memoria
  output reg        mem_write,    // Control de escritura en memoria
  output reg        mem_to_reg,   // Selección entre ALU o memoria para WB
  output reg        reg_write,    // Habilitación de escritura en banco de registros
  output reg  [3:0] byte_mask,    // Máscara de bytes para operaciones de memoria
  output reg        is_signed_load, // Indica si es una carga con extensión de signo
  output reg  [2:0] o_branch_type // Tipo de instrucción de salto:
);

  always @(*) begin
    // Valores por defecto
    reg_dst    = `CTRL_REG_DST_RT;     // Por defecto usa rt como registro destino
    alu_src_a  = `CTRL_ALU_SRC_A_REG;  // Por defecto usa rs
    alu_src_b  = `CTRL_ALU_SRC_B_REG;  // Por defecto usa el registro rt
    mem_read   = 1'b0;                 // Por defecto no lee memoria
    mem_write  = 1'b0;                 // Por defecto no escribe memoria
    mem_to_reg = `CTRL_MEM_TO_REG_ALU; // Por defecto usa resultado de ALU
    reg_write  = `CTRL_REG_WRITE_DIS;  // Por defecto no escribe en registros
    byte_mask  = 4'b0000;              // Por defecto no accede a ningún byte
    is_signed_load = 1'b0;             // Por defecto no es una carga con extensión de signo
    o_branch_type = `BRANCH_TYPE_NONE; // Por defecto no es un salto
    
    case(opcode)
      `OPCODE_R_TYPE: begin
        case(funct)
          `FUNC_JR: begin
            o_branch_type = `BRANCH_TYPE_JR;
          end
          
          `FUNC_JALR: begin
            reg_dst       = `CTRL_REG_DST_RD;      // Ya forzamos rd = $31 en la etapa ID
            alu_src_a     = `CTRL_ALU_SRC_A_PC;    // Usa el PC+4
            reg_write     = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra) o el registro rd
            o_branch_type = `BRANCH_TYPE_JALR;
          end

          `FUNC_SRA, `FUNC_SRL, `FUNC_SLL: begin
            reg_dst       = `CTRL_REG_DST_RD;      
            alu_src_a     = `CTRL_ALU_SRC_A_SHAMT;
            reg_write     = `CTRL_REG_WRITE_EN;
          end
          
          default: begin
            reg_dst       = `CTRL_REG_DST_RD;      
            reg_write     = `CTRL_REG_WRITE_EN;
          end
        endcase
      end
      
      `OPCODE_ADDI, `OPCODE_ADDIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa el campo rt
        alu_src_b  = `CTRL_ALU_SRC_B_IMM; // Usa el inmediato
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end

      `OPCODE_LUI: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
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
      end
      
      `OPCODE_LWU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b1111;               // Lee todos los bytes
        is_signed_load = 1'b0;              // LWU no extiende el signo
      end
      
      `OPCODE_LH: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0011;               // Lee los dos bytes menos significativos
        is_signed_load = 1'b1;              // LH extiende el signo
      end
      
      `OPCODE_LHU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0011;               // Lee los dos bytes menos significativos
        is_signed_load = 1'b0;              // LHU no extiende el signo
      end
      
      `OPCODE_LB: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0001;               // Lee el byte menos significativo
        is_signed_load = 1'b1;              // LB extiende el signo
      end
      
      `OPCODE_LBU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_read   = 1'b1;                  // Lee de memoria
        mem_to_reg = `CTRL_MEM_TO_REG_MEM;  // Usa dato de memoria
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
        byte_mask  = 4'b0001;               // Lee el byte menos significativo
        is_signed_load = 1'b0;              // LBU no extiende el signo
      end
      
      // Instrucciones de almacenamiento (Store)
      `OPCODE_SW: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b1111;               // Escribe todos los bytes
      end
      
      `OPCODE_SH: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b0011;               // Escribe los dos bytes menos significativos
      end
      
      `OPCODE_SB: begin
        reg_dst    = `CTRL_REG_DST_RT;      // No importa (no escribe en registros)
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato para calcular dirección
        mem_write  = `CTRL_MEM_WRITE_EN;    // Escribe en memoria
        reg_write  = `CTRL_REG_WRITE_DIS;   // No escribe en registros
        byte_mask  = 4'b0001;               // Escribe el byte menos significativo
      end
      
      `OPCODE_ANDI, `OPCODE_ORI, `OPCODE_XORI, `OPCODE_SLTI, `OPCODE_SLTIU, `OPCODE_XORI, `OPCODE_SLTI, `OPCODE_SLTIU: begin
        reg_dst    = `CTRL_REG_DST_RT;      // Usa rt como destino
        alu_src_b  = `CTRL_ALU_SRC_B_IMM;   // Usa el inmediato
        mem_to_reg = `CTRL_MEM_TO_REG_ALU;  // Usa resultado de ALU
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en registros
      end
      
      `OPCODE_BEQ: begin
        o_branch_type = `BRANCH_TYPE_BEQ;
      end
      
      `OPCODE_BNE: begin
        o_branch_type = `BRANCH_TYPE_BNE;
      end
      
      `OPCODE_J: begin
        o_branch_type = `BRANCH_TYPE_J;    
      end
      
      `OPCODE_JAL: begin
        reg_dst    = `CTRL_REG_DST_RD;      // Forzamos rd = $31 en la etapa ID
        alu_src_a  = `CTRL_ALU_SRC_A_PC;    // Usa el PC+4  
        reg_write  = `CTRL_REG_WRITE_EN;    // Escribe en $31 (ra)
        o_branch_type = `BRANCH_TYPE_JAL;
      end
    endcase
  end

endmodule

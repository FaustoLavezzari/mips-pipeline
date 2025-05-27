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
  output reg        branch       // Indica si es una instrucción de salto
);

  always @(*) begin
    // Valores por defecto
    reg_dst    = 1'b0;     // Por defecto usa rt como registro destino
    alu_src    = 1'b0;     // Por defecto usa el registro rt
    alu_op     = `ALU_OP_ADD;  // Por defecto suma
    mem_read   = 1'b0;     // Por defecto no lee memoria
    mem_write  = 1'b0;     // Por defecto no escribe memoria
    mem_to_reg = 1'b0;     // Por defecto usa resultado de ALU
    reg_write  = 1'b0;     // Por defecto no escribe en registros
    branch     = 1'b0;     // Por defecto no es instrucción de salto
    
    case(opcode)
      `OPCODE_R_TYPE: begin
        reg_dst    = 1'b1;  // Usa el campo rd
        alu_src    = 1'b0;  // Usa el registro rt
        alu_op     = 2'b10; // Operación R-type (depende del campo function)
        mem_read   = 1'b0;  
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // Usa resultado de ALU
        reg_write  = 1'b1;  // Escribe en registros
      end
      
      `OPCODE_ADDI, `OPCODE_ADDIU: begin
        reg_dst    = 1'b0;  // Usa el campo rt
        alu_src    = 1'b1;  // Usa el inmediato
        alu_op     = 2'b00; // Suma directa
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // Usa resultado de ALU
        reg_write  = 1'b1;  // Escribe en registros
      end
      
      `OPCODE_LW: begin
        reg_dst    = 1'b0;  // Usa rt como destino
        alu_src    = 1'b1;  // Usa el inmediato para calcular dirección
        alu_op     = 2'b00; // Suma para dirección
        mem_read   = 1'b1;  // Lee de memoria
        mem_write  = 1'b0;
        mem_to_reg = 1'b1;  // Usa dato de memoria
        reg_write  = 1'b1;  // Escribe en registros
      end
      
      `OPCODE_SW: begin
        reg_dst    = 1'b0;  // No importa (no escribe en registros)
        alu_src    = 1'b1;  // Usa el inmediato para calcular dirección
        alu_op     = 2'b00; // Suma para dirección
        mem_read   = 1'b0;
        mem_write  = 1'b1;  // Escribe en memoria
        mem_to_reg = 1'b0;  // No importa
        reg_write  = 1'b0;  // No escribe en registros
      end
      
      `OPCODE_ANDI: begin
        reg_dst    = 1'b0;  // Usa rt como destino
        alu_src    = 1'b1;  // Usa el inmediato
        alu_op     = 2'b11; // AND directo
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // Usa resultado de ALU
        reg_write  = 1'b1;  // Escribe en registros
      end
      
      `OPCODE_ORI: begin
        reg_dst    = 1'b0;  // Usa rt como destino
        alu_src    = 1'b1;  // Usa el inmediato
        alu_op     = 2'b11; // OR directo
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // Usa resultado de ALU
        reg_write  = 1'b1;  // Escribe en registros
        branch     = 1'b0;  // No es salto
      end
      
      `OPCODE_SLTI: begin
        reg_dst    = 1'b0;  // Usa rt como destino
        alu_src    = 1'b1;  // Usa el inmediato
        alu_op     = 2'b11; // Operación SLT
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // Usa resultado de ALU
        reg_write  = 1'b1;  // Escribe en registros
        branch     = 1'b0;  // No es salto
      end
      
      `OPCODE_BEQ: begin
        reg_dst    = 1'b0;  // No importa (no escribe en registros)
        alu_src    = 1'b0;  // Usa el registro rt
        alu_op     = 2'b01; // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // No importa
        reg_write  = 1'b0;  // No escribe en registros
        branch     = 1'b1;  // Es salto
      end
      
      `OPCODE_BNE: begin
        reg_dst    = 1'b0;  // No importa (no escribe en registros)
        alu_src    = 1'b0;  // Usa el registro rt
        alu_op     = 2'b01; // Resta para comparación
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;  // No importa
        reg_write  = 1'b0;  // No escribe en registros
        branch     = 1'b1;  // Es salto
      end
      
      default: begin
        // Valores por defecto para instrucciones no implementadas
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        branch     = 1'b0;
      end
    endcase
  end

endmodule

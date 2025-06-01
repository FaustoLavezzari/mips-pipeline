`timescale 1ns / 1ps

module forwarding_unit (
  // Registros fuente en la etapa EX
  input  wire [4:0] i_ex_rs,         // Registro fuente 1 en EX
  input  wire [4:0] i_ex_rt,         // Registro fuente 2 en EX
  
  // Información del registro destino en MEM
  input  wire [4:0] i_mem_rd,        // Registro destino en MEM
  input  wire       i_mem_reg_write, // Señal de escritura en registro en MEM
  
  // Información del registro destino en WB
  input  wire [4:0] i_wb_rd,         // Registro destino en WB
  input  wire       i_wb_reg_write,  // Señal de escritura en registro en WB
  
  // Señales de control de forwarding
  output reg [1:0]  o_forward_a,     // Control de forwarding para operando A
  output reg [1:0]  o_forward_b      // Control de forwarding para operando B
);

  // Codificación para señales de control:
  // 00: No hay forwarding, usar valor del registro
  // 01: Forwarding desde etapa MEM
  // 10: Forwarding desde etapa WB

  always @* begin
    // Inicializar señales por defecto
    o_forward_a = 2'b00;
    o_forward_b = 2'b00;
    
    // EX/MEM Forwarding (prioridad más alta)
    // Para el operando A (RS) - usado para calcular direcciones en LW/SW
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rs)) begin
      o_forward_a = 2'b01;
    end
    // Para el operando B (RT)
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rt)) begin
      o_forward_b = 2'b01;
    end
    
    // MEM/WB Forwarding (prioridad más baja)
    // Para el operando A (RS)
    if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_ex_rs) && 
        // Asegurarse que no haya sido ya resuelto por EX/MEM
        !(i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rs))) begin
      o_forward_a = 2'b10;
    end
    // Para el operando B (RT)
    if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_ex_rt) && 
        // Asegurarse que no haya sido ya resuelto por EX/MEM
        !(i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rt))) begin
      o_forward_b = 2'b10;
    end
    
    // Caso especial: Forwarding para instrucciones que comparan valores (BEQ, BNE)
    // El forwarding debe ser preciso para evitar errores en predicción de saltos
  end

endmodule

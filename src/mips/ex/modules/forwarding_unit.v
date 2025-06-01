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
  // 01: Forwarding desde etapa MEM (EX/MEM) - mayor prioridad
  // 10: Forwarding desde etapa WB (MEM/WB) - menor prioridad

  always @* begin
    // La implementación debe seguir un orden estricto de prioridad
    // Versión mejorada sin condiciones anidadas para mayor claridad
    
    // Forwarding para operando A (RS)
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rs)) begin
      // EX/MEM forwarding - tiene la mayor prioridad
      o_forward_a = 2'b01;
    end
    else if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_ex_rs)) begin
      // MEM/WB forwarding - solo si no hay EX/MEM forwarding
      o_forward_a = 2'b10;
    end
    else begin
      // Ningún forwarding necesario
      o_forward_a = 2'b00;
    end
    
    // Forwarding para operando B (RT)
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rt)) begin
      // EX/MEM forwarding - tiene la mayor prioridad
      o_forward_b = 2'b01;
    end
    else if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_ex_rt)) begin
      // MEM/WB forwarding - solo si no hay EX/MEM forwarding
      o_forward_b = 2'b10;
    end
    else begin
      // Ningún forwarding necesario
      o_forward_b = 2'b00;
    end
    
    // Nota: Esta implementación garantiza una prioridad clara:
    // 1. Primero, se considera el forwarding desde EX/MEM (más reciente)
    // 2. Si no aplica, se considera el forwarding desde MEM/WB (menos reciente)
    // 3. Si ninguno aplica, no se hace forwarding
    
    // Debug: mostrar información sobre forwarding para facilitar depuración
    if (o_forward_a != 2'b00 || o_forward_b != 2'b00) begin
      $display("FORWARDING: RS=%d, RT=%d, MEM_Rd=%d, WB_Rd=%d, ForwardA=%d, ForwardB=%d",
               i_ex_rs, i_ex_rt, i_mem_rd, i_wb_rd, o_forward_a, o_forward_b);
    end
    // Esta estructura elimina la necesidad de condiciones complejas y es más clara.
  end

endmodule

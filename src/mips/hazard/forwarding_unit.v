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
  output wire [1:0]  o_forward_a,    // Control de forwarding para operando A
  output wire [1:0]  o_forward_b     // Control de forwarding para operando B
);

  // Codificación para señales de control:
  // 00: No hay forwarding, usar valor del registro (ID/EX)
  // 01: Forwarding desde etapa MEM (EX/MEM)
  // 10: Forwarding desde etapa WB (MEM/WB)
  
  assign o_forward_a = (i_mem_rd == i_ex_rs && i_ex_rs != 0 && i_mem_reg_write) ? 2'b01 :
                       (i_wb_rd == i_ex_rs && i_ex_rs != 0 && i_wb_reg_write) ? 2'b10 : 
                       2'b00;
                       
  assign o_forward_b = (i_mem_rd == i_ex_rt && i_ex_rt != 0 && i_mem_reg_write) ? 2'b01 :
                       (i_wb_rd == i_ex_rt && i_ex_rt != 0 && i_wb_reg_write) ? 2'b10 : 
                       2'b00;

endmodule

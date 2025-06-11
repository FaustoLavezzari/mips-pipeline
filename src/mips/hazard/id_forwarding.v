`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module id_forwarding (
  // Registros fuente en la etapa ID
  input  wire [4:0] i_id_rs,         // Registro fuente 1 en ID
  input  wire [4:0] i_id_rt,         // Registro fuente 2 en ID
  
  // Información del registro destino en EX
  input  wire [4:0] i_ex_rd,         // Registro destino en EX
  input  wire       i_ex_reg_write,  // Señal de escritura en registro en EX
  
  // Información del registro destino en MEM
  input  wire [4:0] i_mem_rd,        // Registro destino en MEM
  input  wire       i_mem_reg_write, // Señal de escritura en registro en MEM
  
  // Información del registro destino en WB
  input  wire [4:0] i_wb_rd,         // Registro destino en WB
  input  wire       i_wb_reg_write,  // Señal de escritura en registro en WB
  
  // Señales de control de forwarding
  output wire [1:0]  o_forward_a,    // Control de forwarding para RS
  output wire [1:0]  o_forward_b     // Control de forwarding para RT
);

  // Codificación para señales de control:
  // 00: No hay forwarding, usar valor del registro
  // 01: Forwarding desde etapa EX
  // 10: Forwarding desde etapa MEM
  // 11: Forwarding desde etapa WB
  
  assign o_forward_a = (i_ex_rd == i_id_rs && i_id_rs != 0 && i_ex_reg_write) ? 2'b01 :
                       (i_mem_rd == i_id_rs && i_id_rs != 0 && i_mem_reg_write) ? 2'b10 : 
                       (i_wb_rd == i_id_rs && i_id_rs != 0 && i_wb_reg_write) ? 2'b11 : 
                       2'b00;
                       
  assign o_forward_b = (i_ex_rd == i_id_rt && i_id_rt != 0 && i_ex_reg_write) ? 2'b01 :
                       (i_mem_rd == i_id_rt && i_id_rt != 0 && i_mem_reg_write) ? 2'b10 : 
                       (i_wb_rd == i_id_rt && i_id_rt != 0 && i_wb_reg_write) ? 2'b11 : 
                       2'b00;

endmodule

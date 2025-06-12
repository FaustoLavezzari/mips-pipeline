`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module id_forwarding (
  // Registros fuente en la etapa ID
  input  wire [4:0] i_id_rs,         // Registro fuente 1 en ID
  input  wire [4:0] i_id_rt,         // Registro fuente 2 en ID
  
  // Información del registro destino en EX
  input  wire [4:0] i_ex_rd,         // Registro destino en EX
  input  wire       i_ex_reg_write,  // Señal de escritura en registro en EX
  input  wire [31:0] i_ex_alu_result, // Resultado ALU en EX
  
  // Información del registro destino en MEM
  input  wire [4:0] i_mem_rd,        // Registro destino en MEM
  input  wire       i_mem_reg_write, // Señal de escritura en registro en MEM
  input  wire [31:0] i_mem_alu_result, // Resultado ALU en MEM
  
  // Información del registro destino en WB
  input  wire [4:0] i_wb_rd,         // Registro destino en WB
  input  wire       i_wb_reg_write,  // Señal de escritura en registro en WB
  input  wire [31:0] i_wb_write_data, // Dato de WB
  
  // Señales de control y valores de forwarding
  output wire       o_use_forwarded_a,    // Señal para usar valor forwardeado para RS (1) o valor del registro (0)
  output wire       o_use_forwarded_b,    // Señal para usar valor forwardeado para RT (1) o valor del registro (0)
  output wire [31:0] o_forwarded_value_a, // Valor forwardeado para RS
  output wire [31:0] o_forwarded_value_b  // Valor forwardeado para RT
);

  // Codificación para señales de control:
  // 00: No hay forwarding, usar valor del registro
  // 01: Forwarding desde etapa EX
  // 10: Forwarding desde etapa MEM
  // 11: Forwarding desde etapa WB
  
  // Señales de control para forwarding
  wire forward_ex_rs = (i_ex_rd == i_id_rs && i_id_rs != 0 && i_ex_reg_write);
  wire forward_mem_rs = (i_mem_rd == i_id_rs && i_id_rs != 0 && i_mem_reg_write);
  wire forward_wb_rs = (i_wb_rd == i_id_rs && i_id_rs != 0 && i_wb_reg_write);
  
  wire forward_ex_rt = (i_ex_rd == i_id_rt && i_id_rt != 0 && i_ex_reg_write);
  wire forward_mem_rt = (i_mem_rd == i_id_rt && i_id_rt != 0 && i_mem_reg_write);
  wire forward_wb_rt = (i_wb_rd == i_id_rt && i_id_rt != 0 && i_wb_reg_write);
  
  // Determinar si es necesario usar forwardeo para cada operando
  assign o_use_forwarded_a = forward_ex_rs || forward_mem_rs || forward_wb_rs;
  assign o_use_forwarded_b = forward_ex_rt || forward_mem_rt || forward_wb_rt;
  
  // Selección de los valores forwardeados (prioridad: EX > MEM > WB)
  assign o_forwarded_value_a = forward_ex_rs ? i_ex_alu_result :
                              forward_mem_rs ? i_mem_alu_result :
                              forward_wb_rs ? i_wb_write_data :
                              32'b0; // Este valor no se usará cuando o_use_forwarded_a sea 0
                              
  assign o_forwarded_value_b = forward_ex_rt ? i_ex_alu_result :
                              forward_mem_rt ? i_mem_alu_result :
                              forward_wb_rt ? i_wb_write_data :
                              32'b0; // Este valor no se usará cuando o_use_forwarded_b sea 0

endmodule

`timescale 1ns / 1ps

module forwarding_unit (
  // Registros fuente en la etapa EX
  input  wire [4:0] i_ex_rs,         // Registro fuente 1 en EX
  input  wire [4:0] i_ex_rt,         // Registro fuente 2 en EX
  
  // Información del registro destino en MEM
  input  wire [4:0] i_mem_rd,        // Registro destino en MEM
  input  wire       i_mem_reg_write, // Señal de escritura en registro en MEM
  input  wire [31:0] i_mem_result,   // Resultado de la etapa MEM
  
  // Información del registro destino en WB
  input  wire [4:0] i_wb_rd,         // Registro destino en WB
  input  wire       i_wb_reg_write,  // Señal de escritura en registro en WB
  input  wire [31:0] i_wb_result,    // Resultado de la etapa WB
  
  // Señales de control de forwarding
  output wire       o_use_forwarded_a,    // Señal para usar valor forwardeado para RS
  output wire       o_use_forwarded_b,    // Señal para usar valor forwardeado para RT
  output wire [31:0] o_forwarded_value_a, // Valor forwardeado para RS
  output wire [31:0] o_forwarded_value_b  // Valor forwardeado para RT
);

  // Señales de control para forwarding
  wire forward_mem_rs = (i_mem_rd == i_ex_rs && i_ex_rs != 0 && i_mem_reg_write);
  wire forward_wb_rs = (i_wb_rd == i_ex_rs && i_ex_rs != 0 && i_wb_reg_write);
  
  wire forward_mem_rt = (i_mem_rd == i_ex_rt && i_ex_rt != 0 && i_mem_reg_write);
  wire forward_wb_rt = (i_wb_rd == i_ex_rt && i_ex_rt != 0 && i_wb_reg_write);
  
  // Determinar si es necesario usar forwarding
  assign o_use_forwarded_a = forward_mem_rs || forward_wb_rs;
  assign o_use_forwarded_b = forward_mem_rt || forward_wb_rt;
  
  // Selección de los valores forwardeados (prioridad: MEM > WB)
  assign o_forwarded_value_a = forward_mem_rs ? i_mem_result :
                              forward_wb_rs ? i_wb_result :
                              32'b0; // Este valor no se usará cuando o_use_forwarded_a sea 0
                              
  assign o_forwarded_value_b = forward_mem_rt ? i_mem_result :
                              forward_wb_rt ? i_wb_result :
                              32'b0; // Este valor no se usará cuando o_use_forwarded_b sea 0

endmodule

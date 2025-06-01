`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module wb_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde MEM/WB
  input  wire [31:0] i_alu_result,     // Resultado de la ALU
  input  wire [31:0] i_read_data,      // Dato leído de memoria
  input  wire [4:0]  i_write_register, // Registro destino
  input  wire        i_reg_write,      // Control de escritura en registros
  input  wire        i_mem_to_reg,     // Selección entre ALU o memoria
  
  // Salidas para retroalimentación
  output wire [31:0] o_write_data,     // Dato a escribir en el banco de registros
  output wire [4:0]  o_write_register, // Registro destino
  output wire        o_reg_write       // Control de escritura en registros
);

  // Selecciona el dato a escribir en el banco de registros
  assign o_write_data = (i_mem_to_reg) ? i_read_data : i_alu_result;
  
  // Propagar las señales de control
  assign o_write_register = i_write_register;
  assign o_reg_write = i_reg_write;

  // Lógica de selección MUX
  wire [31:0] write_data_out;
  assign write_data_out = (i_mem_to_reg) ? i_read_data : i_alu_result;
  
  // Debug específico para el registro $3
  always @(posedge clk) begin
    if (i_reg_write && i_write_register == 3) begin
      $display("DEBUG_REG_3: Ciclo=%0t, Escribiendo %0d en registro $3 (enable=%b)", 
               $time, write_data_out, i_reg_write);
    end
  end

endmodule

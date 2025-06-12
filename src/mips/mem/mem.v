`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde EX/MEM
  input  wire [31:0] alu_result_in,    // Dirección para LW/SW
  input  wire [31:0] write_data_in,    // Dato a escribir (para SW)
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,     // Señal de escritura en registros
  input  wire        mem_read_in,      // Control de lectura
  input  wire        mem_write_in,     // Control de escritura
  input  wire        mem_to_reg_in,    // Selección ALU/MEM para WB
  input  wire [5:0]  opcode_in,        // Opcode para identificar tipo de carga
  
  // Salidas
  output wire [31:0] read_data_out,    // Dato leído de memoria (para LW)
  output wire [31:0] alu_result_out,   // Pasar el resultado de la ALU a WB
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,    // Señal de escritura en registros
  output wire        mem_to_reg_out   // Selección ALU/MEM para WB
);

  // Instanciar el módulo de memoria de datos
  data_memory data_mem (
    .clk(clk),
    .reset(reset),
    .address_in(alu_result_in),
    .write_data_in(write_data_in),
    .mem_read_in(mem_read_in),
    .mem_write_in(mem_write_in),
    .opcode_in(opcode_in),
    .read_data_out(read_data_out)
  );
  
  // Propagar señales de control y datos
  assign alu_result_out = alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign mem_to_reg_out = mem_to_reg_in;

endmodule

`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde EX/MEM
  input  wire [31:0] alu_result_in,    // Dirección para LW/SW
  input  wire [31:0] write_data_in,    // Dato a escribir (para SW)
  input  wire [4:0]  write_register_in,// Registro destino para WB
  input  wire        reg_write_in,     // Señal de escritura en registros
  input  wire        mem_read_in,      // Control de lectura
  input  wire        mem_write_in,     // Control de escritura
  input  wire        mem_to_reg_in,    // Selección ALU/MEM para WB
  input  wire        is_halt_in,       // Señal de HALT (para detener el pipeline)
  input  wire [3:0]  byte_mask_in,     // Máscara de bytes para memoria
  input  wire        is_signed_load_in, // Indica si es una carga con extensión de signo
  // Debug ports
  input  wire [31:0] i_debug_addr,      // Dirección de depuración
  output wire [31:0] o_debug_data,      // Dato leído de depuración
  // Salidas
  output wire [31:0] write_data_out,     // Valor a escribir en registro
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,      // Señal de escritura en registros
  output wire        is_halt_out         // Señal de HALT para la siguiente etapa
);

  // Señales internas
  wire [31:0] filtered_read_data; // Datos ya filtrados desde la memoria
  
  // Instanciar el módulo de memoria de datos con filtrado integrado
  data_memory data_mem (
    .clk(clk),
    .reset(reset),
    .address_in(alu_result_in),
    .write_data_in(write_data_in),
    .mem_write_in(mem_write_in),
    .mem_read_in(mem_read_in),
    .byte_mask(byte_mask_in),
    .read_data_out(filtered_read_data),
    .i_debug_addr(i_debug_addr),
    .o_debug_data(o_debug_data)
  );
  
  // Señal intermedia para el procesamiento de extensión de signo
  wire [31:0] read_mem_data;
  
  // Instanciar el módulo de extensión de signo condicional
  conditional_sign_extend sign_extend_inst (
    .data_in(filtered_read_data),
    .byte_mask(byte_mask_in),
    .is_signed_load(is_signed_load_in),
    .data_out(read_mem_data)
  );

  assign write_data_out = mem_to_reg_in ? read_mem_data : alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign is_halt_out = is_halt_in;

endmodule

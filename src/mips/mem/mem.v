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
  output wire [31:0] read_data_out,      // Dato leído de memoria (para LW)
  output wire [31:0] alu_result_out,     // Pasar el resultado de la ALU a WB
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,      // Señal de escritura en registros
  output wire        mem_to_reg_out,     // Selección ALU/MEM para WB
  output wire        is_halt_out         // Señal de HALT para la siguiente etapa
);

  // Señales internas
  wire [31:0] raw_read_data; // Datos sin filtrar de la memoria
  
  // Instanciar el módulo de memoria de datos con la nueva interfaz
  data_memory data_mem (
    .clk(clk),
    .reset(reset),
    .address_in(alu_result_in),
    .write_data_in(write_data_in),
    .mem_write_in(mem_write_in),
    .mem_read_in(mem_read_in),
    .byte_mask(byte_mask_in),
    .read_data_out(raw_read_data),
    .i_debug_addr(i_debug_addr),
    .o_debug_data(o_debug_data)
  );
  
  // Filtrar los datos leídos según la máscara de bytes
  wire [7:0] byte0 = byte_mask_in[0] ? raw_read_data[7:0]   : 8'b0;
  wire [7:0] byte1 = byte_mask_in[1] ? raw_read_data[15:8]  : 8'b0;
  wire [7:0] byte2 = byte_mask_in[2] ? raw_read_data[23:16] : 8'b0;
  wire [7:0] byte3 = byte_mask_in[3] ? raw_read_data[31:24] : 8'b0;
  
  // Datos filtrados antes de extensión de signo
  wire [31:0] filtered_data = {byte3, byte2, byte1, byte0};
  
  // Aplicar extensión de signo según la máscara y la señal is_signed_load_in
  assign read_data_out = 
    // Para LB: extender desde bit 7 si es carga con signo y solo se leen 8 bits
    (is_signed_load_in && byte_mask_in == 4'b0001) ? 
      {{24{filtered_data[7]}}, filtered_data[7:0]} :
    // Para LH: extender desde bit 15 si es carga con signo y solo se leen 16 bits
    (is_signed_load_in && byte_mask_in == 4'b0011) ? 
      {{16{filtered_data[15]}}, filtered_data[15:0]} :
    // Para todos los demás casos, usar los datos sin modificar
    filtered_data;
  
  // Propagar señales de control y datos
  assign alu_result_out = alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign mem_to_reg_out = mem_to_reg_in;
  assign is_halt_out = is_halt_in;

endmodule

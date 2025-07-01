`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module data_memory(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas de control y direcciones
  input  wire [31:0] address_in,       // Dirección por bytes
  input  wire [31:0] write_data_in,    // Dato completo a escribir (32 bits)
  input  wire        mem_write_in,     // Control de escritura
  input  wire        mem_read_in,      // Control de lectura
  input  wire [3:0]  byte_mask,        // Máscara de bytes (1 bit por cada byte, activo alto)
  // Debug ports
  input  wire [31:0] i_debug_addr,     // Dirección de depuración
  output wire [31:0] o_debug_data,     // Dato leído de depuración
  // Salidas
  output wire [31:0] read_data_out     // Dato leído de memoria
);

  // Memoria de datos (128 bytes = 32 palabras de 32 bits)
  reg [7:0] memory [0:127];
  
  // Direcciones de byte para acceso a memoria
  wire [31:0] base_addr = address_in;
  
  // Variables para el bucle de reset
  integer i;
  
  // Escritura en memoria (síncrona) con reset
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 128; i = i + 1) begin
        memory[i] <= 8'b0;
      end
    end
    else if (mem_write_in) begin
      if (byte_mask[0])
        memory[base_addr] <= write_data_in[7:0];
      if (byte_mask[1])
        memory[base_addr+1] <= write_data_in[15:8];
      if (byte_mask[2])
        memory[base_addr+2] <= write_data_in[23:16];
      if (byte_mask[3])
        memory[base_addr+3] <= write_data_in[31:24];
    end
  end

  // Lectura de memoria - controlada por mem_read_in
  // Combina 4 bytes consecutivos para formar una palabra de 32 bits
  assign read_data_out = mem_read_in ? 
                        {memory[base_addr+3], memory[base_addr+2], memory[base_addr+1], memory[base_addr]} : 
                        32'b0;

  // Debug read: siempre disponible, sin control de mem_read_in
  assign o_debug_data = {memory[i_debug_addr+3], memory[i_debug_addr+2], memory[i_debug_addr+1], memory[i_debug_addr]};

endmodule

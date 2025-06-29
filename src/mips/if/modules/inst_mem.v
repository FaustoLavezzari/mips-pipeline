`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module instr_mem(
  input  wire        clk,
  input  wire        reset,

  // Entradas de control
  input  wire        write_en,
  input  wire        read_en,
  input  wire [31:0] read_addr,       // Dirección por bytes
  input  wire [31:0] write_addr,      // Dirección por bytes
  input  wire [31:0] write_data,      // Dato completo a escribir (32 bits)

  // Salidas
  output wire [31:0] instr            // Instrucción leída
);

  // Memoria de instrucciones (1024 bytes = 256 instrucciones de 32 bits)
  reg [7:0] memory [0:1023];
  
  // Direcciones base para acceso a memoria
  wire [31:0] read_base_addr = read_addr;
  wire [31:0] write_base_addr = write_addr;
  
  // Variable para el bucle de reset
  integer i;
  
  // Escritura en memoria (síncrona) con reset
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 1024; i = i + 1) begin
        memory[i] <= 8'b0;
      end
    end
    else if (write_en) begin
      memory[write_base_addr]   <= write_data[7:0];
      memory[write_base_addr+1] <= write_data[15:8];
      memory[write_base_addr+2] <= write_data[23:16];
      memory[write_base_addr+3] <= write_data[31:24];
    end
  end

  // Lectura de memoria - controlada por read_en
  // Combina 4 bytes consecutivos para formar una instrucción de 32 bits
  assign instr = read_en ? 
                {memory[read_base_addr+3], memory[read_base_addr+2], memory[read_base_addr+1], memory[read_base_addr]} : 
                32'b0;

endmodule

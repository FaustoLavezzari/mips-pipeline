`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module registers_bank
  #(
    // Número de registros y ancho de cada uno
    parameter REGISTERS_BANK_SIZE = 32,
    parameter REGISTERS_SIZE      = `DATA_WIDTH
  )
  (
    input  wire                                    i_clk,          // reloj
    input  wire                                    i_reset,        // clear de todo el banco
    input  wire                                    i_write_enable, // habilita escritura
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_1,       // índice lectura A
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_2,       // índice lectura B
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_write_register,      // índice escritura
    input  wire [REGISTERS_SIZE-1:0]               i_write_data,       // dato a escribir
    output wire [REGISTERS_SIZE-1:0]               o_read_data_1,  
    output wire [REGISTERS_SIZE-1:0]               o_read_data_2         
  );

  // Banco de registros
  reg [REGISTERS_SIZE-1:0] registers [0:REGISTERS_BANK_SIZE-1];
  integer i;

  // Escritura / clear en flanco positivo del reloj
  always @(posedge i_clk) begin
    if (i_reset) begin
      // Clear de todos los registros
      for (i = 0; i < REGISTERS_BANK_SIZE; i = i + 1)
        registers[i] <= {{REGISTERS_SIZE{1'b0}}};
    end
    else if (i_write_enable) begin
      // Escritura condicionada y protección del registro 0
      registers[i_write_register] <= (i_write_register != 0) 
                                    ? i_write_data 
                                    : {{REGISTERS_SIZE{1'b0}}};
    end
  end

  // Lecturas asíncronas
  assign o_read_data_1 = registers[i_read_register_1];
  assign o_read_data_2 = registers[i_read_register_2];

endmodule

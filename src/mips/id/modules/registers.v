`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module registers_bank
  #(
    parameter REGISTERS_BANK_SIZE = 32,
    parameter REGISTERS_SIZE      = `DATA_WIDTH
  )
  (
    input  wire                                    i_clk,            
    input  wire                                    i_reset,           // clear de todo el banco
    input  wire                                    i_write_enable,    // habilita escritura
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_1, // índice lectura A
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_2, // índice lectura B
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_write_register,  // índice escritura
    input  wire [REGISTERS_SIZE-1:0]               i_write_data,      // dato a escribir
    input wire  [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_debug_reg,       
    output wire [REGISTERS_SIZE-1:0]               o_read_data_1,  
    output wire [REGISTERS_SIZE-1:0]               o_read_data_2,
    output wire [REGISTERS_SIZE-1:0]               o_debug_reg_value 
  );

  // Banco de registros
  reg [REGISTERS_SIZE-1:0] registers [0:REGISTERS_BANK_SIZE-1];
  integer i;

  always @(posedge i_clk) begin
    if (i_reset) begin
      for (i = 0; i < REGISTERS_BANK_SIZE; i = i + 1)
        registers[i] <= {{REGISTERS_SIZE{1'b0}}};
    end
    else if (i_write_enable) begin
      if (i_write_register != 0) begin
        registers[i_write_register] <= i_write_data;
      end else begin
        registers[i_write_register] <= {{REGISTERS_SIZE{1'b0}}};
     end
    end
  end

  assign o_read_data_1 = registers[i_read_register_1];
  assign o_read_data_2 = registers[i_read_register_2];
  assign o_debug_reg_value = registers[i_debug_reg];

endmodule

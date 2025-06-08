`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module registers_bank
  #(
    parameter REGISTERS_BANK_SIZE = 32,
    parameter REGISTERS_SIZE      = `DATA_WIDTH
  )
  (
    input  wire                                    i_clk,          
    input  wire                                    i_reset,        
    input  wire                                    i_write_enable, 
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_1,    
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_read_register_2,     
    input  wire [$clog2(REGISTERS_BANK_SIZE)-1:0]  i_write_register,    
    input  wire [REGISTERS_SIZE-1:0]               i_write_data, 
    output wire [REGISTERS_SIZE-1:0]               o_read_data_1,  
    output wire [REGISTERS_SIZE-1:0]               o_read_data_2         
  );

  reg [REGISTERS_SIZE-1:0] registers [0:REGISTERS_BANK_SIZE-1];
  integer i;

  always @(posedge i_clk) begin
    if (i_reset) begin

      for (i = 0; i < REGISTERS_BANK_SIZE; i = i + 1)
        registers[i] <= {{REGISTERS_SIZE{1'b0}}};

    end
    else if (i_write_enable) begin

      registers[i_write_register] <= (i_write_register != 0) 
                                    ? i_write_data 
                                    : {{REGISTERS_SIZE{1'b0}}};

    end
  end

  assign o_read_data_1 = (i_write_enable && (i_read_register_1 == i_write_register) && (i_read_register_1 != 0)) ? 
                          i_write_data : registers[i_read_register_1];
  
  assign o_read_data_2 = (i_write_enable && (i_read_register_2 == i_write_register) && (i_read_register_2 != 0)) ? 
                          i_write_data : registers[i_read_register_2];

endmodule

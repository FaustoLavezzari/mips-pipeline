`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module PC(
  input  wire       clk,
  input  wire       reset,
  input  wire [31:0] next_pc,
  input  wire       halt,            // Señal de HALT para detener el PC
  input  wire       stall,           // Señal de stall para detener el PC
  output reg [31:0] pc
);

  always @(posedge clk) begin
    if (reset) 
      pc <= {`DATA_WIDTH{1'b0}};
    else if (halt || stall)
      pc <= pc;  // Mantener el mismo PC cuando se detecta HALT o stall
    else 
      pc <= next_pc;
  end
endmodule

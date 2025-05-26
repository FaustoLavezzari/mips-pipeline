`timescale 1ns / 1ps

module instr_mem(
  input  wire [31:0] addr,
  output reg  [31:0] instr
);
  // memoria de 256 instrucciones
  reg [31:0] memory [0:255];
  initial begin
    $readmemh("instr_mem.mem", memory);
  end
  always @(*) begin
    instr = memory[addr[9:2]];  // usa bits [9:2] como índice
  end
endmodule

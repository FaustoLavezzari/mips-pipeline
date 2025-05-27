`timescale 1ns / 1ps

module instr_mem(
  input  wire [31:0] addr,
  output reg  [31:0] instr
);
  // memoria de 256 instrucciones
  reg [31:0] memory [0:255];
  integer i;
  initial begin
    // Inicializar toda la memoria con instrucciones NOP (0x00000000)
    for (i = 0; i < 256; i = i + 1) begin
      memory[i] = 32'h00000000;
    end
    
    // Cargar programa desde archivo
    $readmemh("/home/fausto/mips-pipeline/instructions/test_instr.mem", memory);
    
  end
  always @(*) begin
    instr = memory[addr[9:2]];  // usa bits [9:2] como índice
  end
endmodule

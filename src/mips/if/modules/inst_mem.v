`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module instr_mem(
  input  wire        clk,
  input  wire        reset,

  // Entradas de control
  input  wire        write_en,
  input  wire        read_en,
  input  wire [31:0] read_addr,  
  input  wire [31:0] write_addr, 
  input  wire [31:0] write_data,

  // Salidas
  output reg  [31:0] instr
);
  // memoria de 256 instrucciones
  reg [`DATA_WIDTH-1:0] memory [0:255];
  integer i;
  
  // Reset e inicialización de la memoria
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < 256; i = i + 1) begin
        memory[i] <= {`DATA_WIDTH{1'b0}};
      end
    end
    // Escritura en la memoria cuando write_en está activo
    else if (write_en) begin
      memory[write_addr[9:2]] <= write_data;
    end
  end
  
  // Lectura de la memoria (combinacional)
  always @(*) begin
    if (read_en)
      instr = memory[read_addr[9:2]];
    else
      instr = 32'h00000000;
  end
endmodule

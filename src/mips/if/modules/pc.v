`timescale 1ns / 1ps

module PC(
  input  wire       clk,
  input  wire       reset,
  output reg [31:0] pc
);

  always @(posedge clk or posedge reset) begin
    if (reset) 
      pc <= 32'h00000000;
    else 
      pc <= pc + 4;
  end
endmodule

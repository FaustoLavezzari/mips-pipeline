`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_wb(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde la etapa MEM
  input  wire [31:0] alu_result_in,     // Resultado de la ALU
  input  wire [31:0] read_data_in,      // Dato leído de memoria
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,      // Control de escritura en registros
  input  wire        mem_to_reg_in,     // Selección entre ALU o memoria para WB
  
  // Salidas hacia la etapa WB
  output reg  [31:0] alu_result_out,    // Resultado de la ALU
  output reg  [31:0] read_data_out,     // Dato leído de memoria
  output reg  [4:0]  write_register_out,// Registro destino para WB
  output reg         reg_write_out,     // Control de escritura en registros
  output reg         mem_to_reg_out     // Selección entre ALU o memoria para WB
);

  always @(posedge clk) begin
    if (reset) begin
      alu_result_out     <= {`DATA_WIDTH{1'b0}};
      read_data_out      <= {`DATA_WIDTH{1'b0}};
      write_register_out <= {`REG_ADDR_WIDTH{1'b0}};
      reg_write_out      <= `CTRL_REG_WRITE_DIS;  // Deshabilitar la escritura en reset
      mem_to_reg_out     <= `CTRL_MEM_TO_REG_ALU;
    end else begin
      alu_result_out     <= alu_result_in;
      read_data_out      <= read_data_in;
      write_register_out <= write_register_in;
      reg_write_out      <= reg_write_in;
      mem_to_reg_out     <= mem_to_reg_in;
    end
  end

endmodule

`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module ex_mem(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde la etapa EX
  input  wire [31:0] alu_result_in,     // Resultado de la ALU
  input  wire [31:0] read_data_2_in,    // Valor del registro rt
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,      // Nueva señal - control de escritura en registros
  
  // Señales de control entrantes
  input  wire        mem_read_in,       // Control de lectura de memoria
  input  wire        mem_write_in,      // Control de escritura en memoria
  input  wire        mem_to_reg_in,     // Selecciona entre ALU o memoria para WB
  
  // Salidas hacia la etapa MEM
  output reg  [31:0] alu_result_out,    // Resultado de la ALU
  output reg  [31:0] read_data_2_out,   // Valor del registro rt
  output reg  [4:0]  write_register_out,// Registro destino para WB
  output reg         reg_write_out,     // Señal de escritura en registros
  output reg         mem_read_out,      // Control de lectura de memoria
  output reg         mem_write_out,     // Control de escritura en memoria
  output reg         mem_to_reg_out     // Selecciona entre ALU o memoria para WB
);

  always @(posedge clk) begin
    if (reset) begin
      alu_result_out     <= {`DATA_WIDTH{1'b0}};
      read_data_2_out    <= {`DATA_WIDTH{1'b0}};
      write_register_out <= {`REG_ADDR_WIDTH{1'b0}};
      reg_write_out     <= `CTRL_REG_WRITE_DIS;  // Reset de la señal reg_write - importante para evitar escrituras incorrectas
      mem_read_out      <= 1'b0;                // Reset de la señal mem_read
      mem_write_out     <= 1'b0;                // Reset de la señal mem_write
      mem_to_reg_out    <= `CTRL_MEM_TO_REG_ALU; // Reset de la señal mem_to_reg
    end else begin
      alu_result_out     <= alu_result_in;
      read_data_2_out    <= read_data_2_in;
      write_register_out <= write_register_in;
      reg_write_out     <= reg_write_in;   // Propagar la señal reg_write
      mem_read_out      <= mem_read_in;    // Propagar la señal mem_read
      mem_write_out     <= mem_write_in;   // Propagar la señal mem_write
      mem_to_reg_out    <= mem_to_reg_in;  // Propagar la señal mem_to_reg
    end
  end

endmodule

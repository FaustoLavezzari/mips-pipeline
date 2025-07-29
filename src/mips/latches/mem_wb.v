`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_wb(
  input  wire        clk,
  input  wire        reset,
  input  wire        stall,
  
  // Entradas desde la etapa MEM
  input  wire [31:0] write_data_in,
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,      // Control de escritura en registros
  input  wire        is_halt_in,          // Señal de HALT (para detener el pipeline)
  
  // Salidas hacia la etapa WB
  output reg  [31:0] write_data_out,     // Dato a escribir en el banco de registros
  output reg  [4:0]  write_register_out,// Registro destino para WB
  output reg         reg_write_out,     // Control de escritura en registros
  output reg         is_halt_out        // Señal de HALT para la siguiente etapa
);

  always @(posedge clk) begin
    if (reset) begin
      write_data_out     <= {`DATA_WIDTH{1'b0}};
      write_register_out <= {`REG_ADDR_WIDTH{1'b0}};
      reg_write_out      <= `CTRL_REG_WRITE_DIS;
      is_halt_out        <= 1'b0;                  
    end else if (!stall) begin
      write_data_out     <= write_data_in;
      write_register_out <= write_register_in;
      reg_write_out      <= reg_write_in;
      is_halt_out        <= is_halt_in;            
    end
  end

endmodule

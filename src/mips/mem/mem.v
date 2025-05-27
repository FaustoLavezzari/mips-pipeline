`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde EX/MEM
  input  wire [31:0] alu_result_in,    // Dirección para LW/SW
  input  wire [31:0] write_data_in,    // Dato a escribir (para SW)
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,     // Señal de escritura en registros
  input  wire        mem_read_in,      // Control de lectura
  input  wire        mem_write_in,     // Control de escritura
  input  wire        mem_to_reg_in,    // Selección ALU/MEM para WB
  
  // Salidas
  output wire [31:0] read_data_out,    // Dato leído de memoria (para LW)
  output wire [31:0] alu_result_out,   // Pasar el resultado de la ALU a WB
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,    // Señal de escritura en registros
  output wire        mem_to_reg_out    // Selección ALU/MEM para WB
);

  // Memoria de datos (256 palabras de 32 bits)
  reg [31:0] memory [0:255];
  
  // Dirección base para el acceso a memoria (cálculo del índice)
  wire [31:0] mem_addr = alu_result_in >> 2;
  
  // Lectura asíncrona
  assign read_data_out = (mem_read_in) ? memory[mem_addr] : {`DATA_WIDTH{1'b0}};
  
  // Escritura síncrona
  always @(posedge clk) begin
    if (reset) begin
      // No es necesario resetear toda la memoria aquí, ya se inicializa en el bloque initial
    end
    else if (mem_write_in) begin
      $display("DEBUG_MEM: Escribiendo %0d en memoria[%0d] (dirección=%0d)", 
               write_data_in, mem_addr, alu_result_in);
      memory[mem_addr] <= write_data_in;
    end
  end

  // Inicialización de la memoria
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1)
      memory[i] = {`DATA_WIDTH{1'b0}};
  end
  
  // Propagar señales de control y datos
  assign alu_result_out = alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign mem_to_reg_out = mem_to_reg_in;
  
  // Mensaje de depuración para operaciones de memoria
  always @(posedge clk) begin
    if (mem_write_in)
      $display("DEBUG_MEM_SIGNALS: mem_write_in=%b, write_data_in=%0d, addr=%0d, calculated_index=%0d", 
               mem_write_in, write_data_in, alu_result_in, alu_result_in >> 2);
    if (mem_read_in)
      $display("DEBUG_MEM_SIGNALS: mem_read_in=%b, addr=%0d, calculated_index=%0d, read_data=%0d", 
               mem_read_in, alu_result_in, alu_result_in >> 2, read_data_out);
  end

endmodule

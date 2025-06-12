`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module data_memory(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas de control y direcciones
  input  wire [31:0] address_in,       // Dirección para LW/SW
  input  wire [31:0] write_data_in,    // Dato a escribir (para SW)
  input  wire        mem_read_in,      // Control de lectura
  input  wire        mem_write_in,     // Control de escritura
  input  wire [5:0]  opcode_in,        // Opcode para identificar tipo de carga
  
  // Salidas
  output wire [31:0] read_data_out     // Dato leído de memoria
);

  // Memoria de datos (256 palabras de 32 bits)
  reg [31:0] memory [0:255];
  
  // Cálculo del índice para acceder a la memoria (dirección dividida por 4)
  wire [31:0] mem_addr_full = address_in >> 2; // División por 4 (palabra alineada)
  wire [7:0] mem_addr = mem_addr_full[7:0]; // Mantener compatibilidad con la definición de memoria
  
  // Variables para el bucle de reset
  integer i;
  
  // Escritura en memoria (síncrona) con reset
  always @(posedge clk) begin
    if (reset) begin
      // Reset síncrono - inicializa todas las posiciones de memoria con un bucle
      for (i = 0; i < 256; i = i + 1) begin
        memory[i] <= 32'b0;
      end
    end
    else if (mem_write_in) begin
      case (opcode_in)
        `OPCODE_SB: begin  // Store Byte
          case (address_in[1:0])
            2'b00: memory[mem_addr] <= {memory[mem_addr][31:8], write_data_in[7:0]};
            2'b01: memory[mem_addr] <= {memory[mem_addr][31:16], write_data_in[7:0], memory[mem_addr][7:0]};
            2'b10: memory[mem_addr] <= {memory[mem_addr][31:24], write_data_in[7:0], memory[mem_addr][15:0]};
            2'b11: memory[mem_addr] <= {write_data_in[7:0], memory[mem_addr][23:0]};
          endcase
        end
        `OPCODE_SH: begin  // Store Halfword
          case (address_in[1])
            1'b0: memory[mem_addr] <= {memory[mem_addr][31:16], write_data_in[15:0]};
            1'b1: memory[mem_addr] <= {write_data_in[15:0], memory[mem_addr][15:0]};
          endcase
        end
        `OPCODE_SW: begin  // Store Word (estándar)
          memory[mem_addr] <= write_data_in;
        end
        default: begin
          memory[mem_addr] <= write_data_in;
        end
      endcase
    end
  end

  // Lectura de memoria (asíncrona)
  reg [31:0] read_data;
  
  always @(*) begin
    if (mem_read_in) begin
      case (opcode_in)
        `OPCODE_LB: begin  // Load Byte (sign-extended)
          case (address_in[1:0])
            2'b00: read_data = {{24{memory[mem_addr][7]}}, memory[mem_addr][7:0]};
            2'b01: read_data = {{24{memory[mem_addr][15]}}, memory[mem_addr][15:8]};
            2'b10: read_data = {{24{memory[mem_addr][23]}}, memory[mem_addr][23:16]};
            2'b11: read_data = {{24{memory[mem_addr][31]}}, memory[mem_addr][31:24]};
          endcase
        end
        `OPCODE_LBU: begin  // Load Byte Unsigned (zero-extended)
          case (address_in[1:0])
            2'b00: read_data = {24'b0, memory[mem_addr][7:0]};
            2'b01: read_data = {24'b0, memory[mem_addr][15:8]};
            2'b10: read_data = {24'b0, memory[mem_addr][23:16]};
            2'b11: read_data = {24'b0, memory[mem_addr][31:24]};
          endcase
        end
        `OPCODE_LH: begin  // Load Halfword (sign-extended)
          case (address_in[1])
            1'b0: read_data = {{16{memory[mem_addr][15]}}, memory[mem_addr][15:0]};
            1'b1: read_data = {{16{memory[mem_addr][31]}}, memory[mem_addr][31:16]};
          endcase
        end
        `OPCODE_LHU: begin  // Load Halfword Unsigned (zero-extended)
          case (address_in[1])
            1'b0: read_data = {16'b0, memory[mem_addr][15:0]};
            1'b1: read_data = {16'b0, memory[mem_addr][31:16]};
          endcase
        end
        `OPCODE_LW: begin  // Load Word (standard)
          read_data = memory[mem_addr];
        end
        `OPCODE_LWU: begin  // Load Word Unsigned (no-op, igual a LW en un sistema de 32 bits)
          read_data = memory[mem_addr];
        end
        default: begin
          read_data = memory[mem_addr]; // Por defecto, cargar palabra completa
        end
      endcase
    end else begin
      read_data = 32'b0;
    end
  end
  
  // Asignar salida
  assign read_data_out = read_data;

endmodule

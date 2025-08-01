`timescale 1ns / 1ps

module byte_filter (
    input  wire [31:0] data_in,      // Datos de entrada de 32 bits
    input  wire [3:0]  byte_mask,    // Máscara de bytes (4 bits)
    output wire [31:0] data_out      // Datos filtrados de salida
);

    // Filtrar cada byte según la máscara
    wire [7:0] byte0 = byte_mask[0] ? data_in[7:0]   : 8'b0;
    wire [7:0] byte1 = byte_mask[1] ? data_in[15:8]  : 8'b0;
    wire [7:0] byte2 = byte_mask[2] ? data_in[23:16] : 8'b0;
    wire [7:0] byte3 = byte_mask[3] ? data_in[31:24] : 8'b0;
    
    // Combinar los bytes filtrados
    assign data_out = {byte3, byte2, byte1, byte0};

endmodule

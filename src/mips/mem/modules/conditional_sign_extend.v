`timescale 1ns / 1ps

module conditional_sign_extend (
    input  wire [31:0] data_in,         // Datos filtrados de entrada
    input  wire [3:0]  byte_mask,       // Máscara de bytes para determinar el ancho
    input  wire        is_signed_load,  // Indica si es una carga con signo
    output wire [31:0] data_out         // Datos con extensión de signo aplicada
);

    // Señales intermedias para diferentes extensiones
    wire [31:0] extended_8bit;   // Para LB (load byte)
    wire [31:0] extended_16bit;  // Para LH (load halfword)
    
    // Instanciar módulos de extensión de signo
    sign_extend #(
        .INPUT_WIDTH(8),
        .OUTPUT_WIDTH(32)
    ) sign_ext_8 (
        .data_in(data_in[7:0]),
        .data_out(extended_8bit)
    );
    
    sign_extend #(
        .INPUT_WIDTH(16),
        .OUTPUT_WIDTH(32)
    ) sign_ext_16 (
        .data_in(data_in[15:0]),
        .data_out(extended_16bit)
    );
    
    // Lógica de selección de extensión de signo
    assign data_out = 
        // Para LB: extender desde bit 7 si es carga con signo y solo se leen 8 bits
        (is_signed_load && byte_mask == 4'b0001) ? extended_8bit :
        // Para LH: extender desde bit 15 si es carga con signo y solo se leen 16 bits
        (is_signed_load && byte_mask == 4'b0011) ? extended_16bit :
        // Para todos los demás casos, usar los datos sin modificar
        data_in;

endmodule

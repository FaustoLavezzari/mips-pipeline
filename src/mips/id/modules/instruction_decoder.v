`timescale 1ns / 1ps

module instruction_decoder(
    input  wire [31:0] i_instruction,           // Instrucción de 32 bits
    
    // Campos básicos de la instrucción
    output wire [5:0]  o_opcode,                // Opcode [31:26]
    output wire [4:0]  o_rs,                    // Registro fuente 1 [25:21]
    output wire [4:0]  o_rt,                    // Registro fuente 2 [20:16]
    output wire [4:0]  o_rd,                    // Registro destino [15:11]
    output wire [5:0]  o_funct,                 // Función [5:0]
    
    // Campos procesados
    output wire [31:0] o_shamt,                 // Shift amount extendido con ceros a 32 bits
    output wire [31:0] o_sign_extended_imm,     // Inmediato con extensión de signo a 32 bits
    output wire [25:0] o_target                 // Campo target para jumps [25:0]
);

    // Extracción de campos básicos
    assign o_opcode = i_instruction[31:26];
    assign o_rs     = i_instruction[25:21];
    assign o_rt     = i_instruction[20:16];
    assign o_rd     = i_instruction[15:11];
    assign o_funct  = i_instruction[5:0];
    assign o_target = i_instruction[25:0];
    
    // Campos intermedios
    wire [4:0]  shamt_raw      = i_instruction[10:6];
    wire [15:0] immediate_raw  = i_instruction[15:0];
    
    // Extensión con ceros del shamt (5 bits -> 32 bits) usando módulo genérico
    zero_extend #(
        .INPUT_WIDTH(5),
        .OUTPUT_WIDTH(32)
    ) shamt_zero_extend (
        .data_in(shamt_raw),
        .data_out(o_shamt)
    );
    
    // Extensión de signo del inmediato (16 bits -> 32 bits)
    sign_extend #(
        .INPUT_WIDTH(16),
        .OUTPUT_WIDTH(32)
    ) imm_sign_extend (
        .data_in(immediate_raw),
        .data_out(o_sign_extended_imm)
    );

endmodule

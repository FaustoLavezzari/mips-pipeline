`timescale 1ns / 1ps


module mux
    #(
        parameter CHANNELS = 2,
        parameter BUS_SIZE = 32
    )
    (
        input  wire [$clog2(CHANNELS) - 1 : 0]    selector,
        input  wire [CHANNELS * BUS_SIZE - 1 : 0] data_in,
        output reg  [BUS_SIZE - 1 : 0]            data_out 
    );

    // Implementación más estable usando always block
    // Evita problemas de timing del shift variable y estados de alta impedancia
    integer i;
    always @(*) begin
        data_out = {BUS_SIZE{1'b0}}; // Default seguro: todos ceros
        
        // Verificar que el selector sea válido
        if (selector < CHANNELS) begin
            // Extraer el canal correspondiente sin usar shift variable
            data_out = data_in[(selector * BUS_SIZE) +: BUS_SIZE];
        end
    end

endmodule
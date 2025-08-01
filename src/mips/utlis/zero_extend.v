`timescale 1ns / 1ps

module zero_extend
    #(
        parameter INPUT_WIDTH = 5,
        parameter OUTPUT_WIDTH = 32
    )
    (
        input  wire [INPUT_WIDTH - 1 : 0]  data_in,
        output wire [OUTPUT_WIDTH - 1 : 0] data_out
    );

    // Verificación de parámetros en tiempo de compilación
    initial begin
        if (OUTPUT_WIDTH <= INPUT_WIDTH) begin
            $error("OUTPUT_WIDTH (%0d) debe ser mayor que INPUT_WIDTH (%0d)", OUTPUT_WIDTH, INPUT_WIDTH);
        end
    end

    // Extensión con ceros: rellena con ceros en los bits superiores
    assign data_out = {{(OUTPUT_WIDTH - INPUT_WIDTH){1'b0}}, data_in};

endmodule

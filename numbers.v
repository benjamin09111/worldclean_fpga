`default_nettype none

module numbers (
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire [3:0] score,  // Número a mostrar (0-9)
    output wire       number_on
);

    // Posición del marcador (Abajo al centro)
    localparam X_POS = 10'd310;
    localparam Y_POS = 10'd440;
    localparam SIZE  = 10'd20; // Tamaño del número

    // Lógica de segmentos para un display de 7 segmentos simulado en coordenadas
    wire [9:0] rel_x = pix_x - X_POS;
    wire [9:0] rel_y = pix_y - Y_POS;
    wire in_box = (pix_x >= X_POS && pix_x < X_POS + SIZE) && 
                  (pix_y >= Y_POS && pix_y < Y_POS + (SIZE*2));

    // Definición de "segmentos" basados en coordenadas relativas
    wire seg_a = (rel_y < 4);                         // Arriba
    wire seg_b = (rel_x >= SIZE-4 && rel_y < SIZE);   // Derecha Arriba
    wire seg_c = (rel_x >= SIZE-4 && rel_y >= SIZE);  // Derecha Abajo
    wire seg_d = (rel_y >= (SIZE*2)-4);               // Abajo
    wire seg_e = (rel_x < 4 && rel_y >= SIZE);        // Izquierda Abajo
    wire seg_f = (rel_x < 4 && rel_y < SIZE);         // Izquierda Arriba
    wire seg_g = (rel_y >= SIZE-2 && rel_y <= SIZE+2);// Centro

    reg [6:0] segments;
    always @(*) begin
        case (score)
            4'd0: segments = 7'b1111110; // abcdef
            4'd1: segments = 7'b0110000; // bc
            4'd2: segments = 7'b1101101; // abdeg
            4'd3: segments = 7'b1111001; // abcdg
            4'd4: segments = 7'b0110011; // bcfg
            4'd5: segments = 7'b1011011; // acdfg
            4'd6: segments = 7'b1011111; // acdefg
            4'd7: segments = 7'b1110000; // abc
            4'd8: segments = 7'b1111111; // abcdefg
            4'd9: segments = 7'b1110011; // abcfg
            default: segments = 7'b0000000;
        endcase
    end

    assign number_on = in_box && (
        (segments[6] && seg_a) || (segments[5] && seg_b) ||
        (segments[4] && seg_c) || (segments[3] && seg_d) ||
        (segments[2] && seg_e) || (segments[1] && seg_f) ||
        (segments[0] && seg_g)
    );

endmodule
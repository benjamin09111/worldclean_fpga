`default_nettype none

module meteor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       h_sync_active, // Se usa para sincronizar el movimiento horizontal
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire [9:0] start_x,     // Posición X inicial (derecha de la pantalla)
    input  wire [9:0] meteor_size, // Tamaño del meteorito (lado del cuadrado)
    input  wire [9:0] meteor_y,    // Posición Y del meteorito (parte superior)
    output wire       meteor_on,   // 1 si el píxel actual es parte de este meteorito
    output wire       passed_screen_left // 1 si el meteorito ha pasado el borde izquierdo
);

    reg [9:0] current_x; // Posición horizontal actual del meteorito

    localparam METEOR_SPEED = 10'd2; // <--- VELOCIDAD DE AVANCE DE LOS METEORITOS

    always @(posedge h_sync_active or negedge rst_n) begin
        if (~rst_n) begin
            current_x <= start_x;
        end else begin
            // Movemos el meteorito hacia la izquierda
            if (current_x < METEOR_SPEED) begin // Evitar underflow
                current_x <= 10'd0; // Ha pasado la pantalla
            end else begin
                current_x <= current_x - METEOR_SPEED;
            end
        end
    end

    // Señal para indicar que ha pasado el borde izquierdo
    assign passed_screen_left = (current_x <= 10'd0); 

    // Dibujar el meteorito (cuadrado rojo)
    assign meteor_on = (pix_x >= current_x && pix_x < current_x + meteor_size) &&
                       (pix_y >= meteor_y && pix_y < meteor_y + meteor_size);

endmodule
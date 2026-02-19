`default_nettype none

module background_stars (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       v_sync,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    output wire       bg_star_on
);

    reg [9:0] offset_x;
    reg [3:0] slow_down; // Contador para hacer el movimiento MUY lento

    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            offset_x <= 0;
            slow_down <= 0;
        end else begin
            // Solo movemos el fondo cada 8 frames (movimiento súper suave)
            slow_down <= slow_down + 1;
            if (slow_down == 4'd8) begin
                slow_down <= 0;
                offset_x <= (offset_x == 639) ? 0 : offset_x + 1;
            end
        end
    end

    // Coordenada del "mundo"
    wire [9:0] world_x = (pix_x + offset_x) % 640;
    
    // --- AJUSTE DE CANTIDAD ---
    // Aumentamos los números para que aparezcan menos estrellas.
    // Solo se dibuja si coinciden estas divisiones exactas.
    wire star_pattern = (world_x == 100 && pix_y == 50)  ||
                        (world_x == 300 && pix_y == 150) ||
                        (world_x == 500 && pix_y == 300) ||
                        (world_x == 150 && pix_y == 400) ||
                        (world_x == 450 && pix_y == 20)  ||
                        (world_x == 50  && pix_y == 450);

    // Mandamos la señal sin dithering para evitar parpadeo visual en el navegador
    assign bg_star_on = star_pattern;

endmodule
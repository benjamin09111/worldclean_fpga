module ship (
    input  wire       clk, 
    input  wire       rst_n, 
    input  wire       v_sync,
    input  wire [9:0] pix_x, 
    input  wire [9:0] pix_y,
    input  wire       move_up, 
    input  wire       move_down,
    output wire [9:0] ship_y_out, 
    output wire       ship_on
);
    reg [9:0] ship_y;

    // Movimiento de la nave
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) 
            ship_y <= 240;
        else begin
            if (move_up && ship_y > 15)       ship_y <= ship_y - 15;
            else if (move_down && ship_y < 435) ship_y <= ship_y + 15;
        end
    end

    assign ship_y_out = ship_y;

    // Coordenadas locales dentro de un cuadro de 32x32
    wire [9:0] lx = pix_x - 40;
    wire [9:0] ly = pix_y - ship_y;
    wire in_box = (pix_x >= 40 && pix_x < 72 && pix_y >= ship_y && pix_y < ship_y + 32);

    // --- Diseño de la Nave (Arte por pixeles) ---
    // Un diseño de 32x32 más estilizado
    wire body   = (lx >= 4  && lx <= 24 && ly >= 12 && ly <= 20); // Cuerpo central
    wire nose   = (lx >= 25 && lx <= 30 && ly >= 14 && ly <= 18); // Punta/Morro
    wire cockpit = (lx >= 12 && lx <= 20 && ly >= 13 && ly <= 19); // Cabina
    wire wing_u = (lx >= 2  && lx <= 10 && ly >= 4  && ly <= 12); // Ala superior
    wire wing_d = (lx >= 2  && lx <= 10 && ly >= 20 && ly <= 28); // Ala inferior
    wire tail   = (lx >= 0  && lx <= 4  && ly >= 8  && ly <= 24); // Alerón trasero

    assign ship_on = in_box && (body || nose || cockpit || wing_u || wing_d || tail);

endmodule
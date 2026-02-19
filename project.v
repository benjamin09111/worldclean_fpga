`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Señales de sincronización y posición
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;

    // Señales de objetos
    wire ship_pixel, meteor_pixel, star_pixel, bg_star_pixel, bullet_pixel, bullet_is_flying;
    wire heart_pixel;
    wire [1:0] current_lives; // <--- Aquí se guardarán las vidas (0, 1 o 2)

    // --- INSTANCIA DE VIDAS (Corazones) ---
    hearts indicador_vidas (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .lives(current_lives), // Conectado a la salida de collisions
        .heart_on(heart_pixel)
    );

    // Señales de estado
    wire m1_alive, m2_alive, m3_alive, s1_alive, s2_alive;
    wire [9:0] current_ship_y;

    // --- LÓGICA DE VELOCIDAD (Se mantiene) ---
    reg [4:0] current_speed;
    always @(*) begin
        if (score >= 4'd7)      current_speed = 5'd26; 
        else if (score >= 4'd5) current_speed = 5'd22; 
        else if (score >= 4'd3) current_speed = 5'd18; 
        else                    current_speed = 5'd15;  
    end

    // --- OBJETOS ---
    meteoritos obstaculos (
        .clk(clk), .rst_n(rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .m1_alive(m1_alive), .m2_alive(m2_alive), .m3_alive(m3_alive),
        .speed_in(current_speed), .score(score), .meteor_on(meteor_pixel)
    );

    ship player_one (
        .clk(clk), .rst_n(rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .move_up(ui_in[0]), .move_down(ui_in[1]), .ship_y_out(current_ship_y), .ship_on(ship_pixel)
    );

    stars fondo_estrellas (
        .clk(clk), .rst_n(rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .s1_alive(s1_alive), .s2_alive(s2_alive), .star_on(star_pixel)
    );

    bullet player_bullet (
        .clk(clk), .rst_n(rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .shoot(ui_in[2]), .ship_x(10'd40), .ship_y(current_ship_y),
        .bullet_active(bullet_is_flying), .bullet_on(bullet_pixel)
    );

    // --- SISTEMA DE COLISIONES (CONECTADO A LIVES) ---
    collisions system_hits (
        .v_sync(vsync),
        .rst_n(rst_n),
        .ship_x(10'd40),
        .ship_y(current_ship_y),
        .m1_x(obstaculos.m1_x), .m1_y(obstaculos.m1_y),
        .m2_x(obstaculos.m2_x), .m2_y(obstaculos.m2_y),
        .m3_x(obstaculos.m3_x), .m3_y(obstaculos.m3_y),
        .s1_x(fondo_estrellas.s1_x), .s1_y(fondo_estrellas.s1_y),
        .s2_x(fondo_estrellas.s2_x), .s2_y(fondo_estrellas.s2_y),
        .b_x(player_bullet.b_x), .b_y(player_bullet.b_y),
        .bullet_active(bullet_is_flying),
        .m1_alive(m1_alive), .m2_alive(m2_alive), .m3_alive(m3_alive),
        .s1_alive(s1_alive), .s2_alive(s2_alive),
        .lives(current_lives) // <--- ¡ESTA ERA LA CONEXIÓN QUE FALTABA!
    );

    // --- SCORE Y NÚMEROS ---
    reg [3:0] score;
    reg s1_prev, s2_prev;
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin score <= 4'd0; s1_prev <= 1'b1; s2_prev <= 1'b1; end
        else begin
            s1_prev <= s1_alive; s2_prev <= s2_alive;
            if ((s1_prev && !s1_alive) || (s2_prev && !s2_alive))
                if (score < 4'd9) score <= score + 1'b1;
        end
    end

    wire score_pixel;
    numbers marcador (
        .pix_x(pix_x), .pix_y(pix_y), .score(score), .number_on(score_pixel)
    );

    // Generador VGA
    hvsync_generator hvsync_gen(
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    // --- LÓGICA DE COLORES FINAL ---
    wire r_bit, g_bit, b_bit;

    // Rojo: Meteoritos, Estrellas amarillas y CORAZONES
    assign r_bit = video_active && (meteor_pixel || star_pixel || heart_pixel);
    
    // Verde: Nave, Estrellas, Bala, Marcador de Score
    assign g_bit = video_active && (ship_pixel || star_pixel || bullet_pixel || score_pixel);
                                
    // Azul: Bala, Score (para hacerlos Cian/Blanco)
    assign b_bit = video_active && (bullet_pixel || score_pixel);

    // Salida final
    assign uo_out = {hsync, b_bit, g_bit, r_bit, vsync, b_bit, g_bit, r_bit};
    assign uio_out = {score, current_lives, m2_alive, m1_alive}; 
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, ui_in[7:3], bg_star_pixel, m3_alive};
endmodule
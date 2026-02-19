`default_nettype none

// --- TOP LEVEL MODULE ---
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

    // --- MÁQUINA DE ESTADOS ---
    localparam STATE_MENU = 2'd0;
    localparam STATE_GAME = 2'd1;
    localparam STATE_END  = 2'd2;
    reg [1:0] state;

    // Control de parpadeo
    reg [5:0] blink_timer; 
    wire blink_menu = blink_timer[3]; // Aún más rápido (Fast Arcade style) 
    wire blink_ship = blink_timer[2];

    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            state <= STATE_MENU;
            blink_timer <= 0;
        end else begin
            blink_timer <= blink_timer + 1'b1;
            case (state)
                STATE_MENU: begin
                    if (ui_in[2]) state <= STATE_GAME;
                end
                STATE_GAME: begin
                    // Fin si score llega a 9 o vidas llegan a 0
                    if (score >= 4'd9 || current_lives == 0) state <= STATE_END;
                end
                STATE_END: begin
                    if (ui_in[2]) state <= STATE_MENU;
                end
            endcase
        end
    end

    // Reset interno para el juego
    wire game_rst_n = rst_n && (state == STATE_GAME);

    // Señales de sincronización y posición
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;

    // Instancia del generador de sincronización
    hvsync_generator hvsync_gen(
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    // --- OBJETOS DEL JUEGO ---
    
    // 1. Nave Jugador
    wire [9:0] current_ship_y;
    wire ship_pixel;
    ship player_one (
        .clk(clk), .rst_n(game_rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .move_up(ui_in[0]), .move_down(ui_in[1]), 
        .ship_y_out(current_ship_y), .ship_on(ship_pixel)
    );

    // 2. Fondo de Estrellas (Lejanas)
    wire bg_star_pixel;
    background_stars bg_layer (
        .clk(clk), .rst_n(game_rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .bg_star_on(bg_star_pixel)
    );

    // 3. Estrellas (Cercanas)
    wire s1_alive, s2_alive;
    wire star_pixel;
    stars fg_layer (
        .clk(clk), .rst_n(game_rst_n), .s1_alive(s1_alive), .s2_alive(s2_alive),
        .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y), .star_on(star_pixel)
    );

    // 4. Meteoritos
    wire m1_alive, m2_alive, m3_alive;
    wire meteor_pixel;
    meteoritos obstaculos (
        .clk(clk), .rst_n(game_rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .m1_alive(m1_alive), .m2_alive(m2_alive), .m3_alive(m3_alive),
        .speed_in(score >= 4'd7 ? 6'd35 : score >= 4'd5 ? 6'd30 : score >= 4'd3 ? 6'd25 : 6'd20),  
        .score(score), .meteor_on(meteor_pixel)
    );

    // 5. Bala
    wire bullet_is_flying, bullet_pixel;
    bullet player_bullet (
        .clk(clk), .rst_n(game_rst_n), .v_sync(vsync), .pix_x(pix_x), .pix_y(pix_y),
        .shoot(ui_in[2]), .ship_x(10'd40), .ship_y(current_ship_y),
        .bullet_active(bullet_is_flying), .bullet_on(bullet_pixel)
    );

    // 6. Colisiones (Lógica del Sistema)
    wire [1:0] current_lives;
    wire is_invulnerable;
    collisions system_hits (
        .v_sync(vsync), .rst_n(game_rst_n),
        .ship_x(10'd40), .ship_y(current_ship_y),
        .m1_x(obstaculos.m1_x), .m1_y(obstaculos.m1_y),
        .m2_x(obstaculos.m2_x), .m2_y(obstaculos.m2_y),
        .m3_x(obstaculos.m3_x), .m3_y(obstaculos.m3_y),
        .s1_x(fg_layer.s1_x), .s1_y(fg_layer.s1_y),
        .s2_x(fg_layer.s2_x), .s2_y(fg_layer.s2_y),
        .b_x(player_bullet.b_x), .b_y(player_bullet.b_y),
        .bullet_active(bullet_is_flying),
        .m1_alive(m1_alive), .m2_alive(m2_alive), .m3_alive(m3_alive),
        .s1_alive(s1_alive), .s2_alive(s2_alive),
        .lives(current_lives),
        .hit_blink(is_invulnerable)
    );

    // 7. Score (Lógica)
    reg [3:0] score;
    reg s1_prev, s2_prev;
    always @(posedge vsync or negedge game_rst_n) begin
        if (~game_rst_n) begin score <= 4'd0; s1_prev <= 1'b1; s2_prev <= 1'b1; end
        else begin
            s1_prev <= s1_alive; s2_prev <= s2_alive;
            if ((s1_prev && !s1_alive) || (s2_prev && !s2_alive))
                if (score < 4'd9) score <= score + 1'b1;
        end
    end

    // --- INTERFAZ DE USUARIO (UI) ---
    
    // Corazones
    wire heart_pixel;
    hearts indicador_vidas (
        .pix_x(pix_x), .pix_y(pix_y), .lives(current_lives), .heart_on(heart_pixel)
    );

    // Números (Score Numérico)
    wire score_pixel;
    numbers marcador (
        .pix_x(pix_x), .pix_y(pix_y), .score(score), .number_on(score_pixel)
    );

    // Texto (Labels, Menu, End)
    wire menu_pixel, end_pixel, labels_pixel;
    game_text display_texto (
        .pix_x(pix_x), .pix_y(pix_y),
        .show_menu(state == STATE_MENU && blink_menu),
        .show_title(state == STATE_MENU), 
        .show_end(state == STATE_END),
        .show_won(state == STATE_END && score >= 4'd9), // Nuevo: Muestra YOU WON si gana
        .show_restart(state == STATE_END && blink_menu), // Nuevo: parpadeo de RESTART
        .pixel_on(menu_pixel), .end_on(end_pixel),
        .labels_on(labels_pixel)
    );

    // --- MEZCLADOR DE COLORES ---
    wire ship_visible = ship_pixel && (!is_invulnerable || blink_ship);
    
    wire r_bit, g_bit, b_bit;
    
    // RED: Meteoritos, Corazones, UI (blanco=R+G+B), Texto Final
    assign r_bit = video_active && (
        (state == STATE_GAME && (meteor_pixel || heart_pixel || score_pixel || labels_pixel)) ||
        (state == STATE_END && end_pixel)
    );
    
    // GREEN: Nave, Balas, Estrellas, UI (blanco), Texto Menu
    assign g_bit = video_active && (
        (state == STATE_GAME && (ship_visible || bullet_pixel || star_pixel || score_pixel || labels_pixel)) ||
        (state == STATE_MENU && menu_pixel)
    );
    
    // BLUE: Balas, Estrellas, Background Stars, UI (blanco), Texto Menu
    assign b_bit = video_active && (
        (state == STATE_GAME && (bullet_pixel || star_pixel || bg_star_pixel || score_pixel || labels_pixel)) ||
        (state == STATE_MENU && menu_pixel)
    );

    assign uo_out = {hsync, b_bit, g_bit, r_bit, vsync, b_bit, g_bit, r_bit};
    assign uio_out = {score, current_lives, state, m1_alive}; 
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, ui_in[7:3], m3_alive}; // m3_alive usado en collisions pero no output directo importante

endmodule

// ============================================================================
//                              MÓDULOS INCLUIDOS
// ============================================================================

module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);
  input clk;
  input reset;
  output reg hsync, vsync;
  output display_on;
  output reg [9:0] hpos;
  output reg [9:0] vpos;

  parameter H_DISPLAY       = 640;
  parameter H_BACK          =  48;
  parameter H_FRONT         =  16;
  parameter H_SYNC          =  96;
  parameter V_DISPLAY       = 480;
  parameter V_TOP           =  33;
  parameter V_BOTTOM        =  10;
  parameter V_SYNC          =   2;
  parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
  parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
  parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
  parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
  parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
  parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

  wire hmaxxed = (hpos == H_MAX) || reset;
  wire vmaxxed = (vpos == V_MAX) || reset;
  
  always @(posedge clk) begin
    hsync <= ~(hpos>=H_SYNC_START && hpos<=H_SYNC_END);
    if(hmaxxed) hpos <= 0; else hpos <= hpos + 1;
  end

  always @(posedge clk) begin
    vsync <= ~(vpos>=V_SYNC_START && vpos<=V_SYNC_END);
    if(hmaxxed) if (vmaxxed) vpos <= 0; else vpos <= vpos + 1;
  end
  
  assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);
endmodule

module background_stars (
    input  wire       clk, input  wire       rst_n, input  wire       v_sync,
    input  wire [9:0] pix_x, input  wire [9:0] pix_y, output wire       bg_star_on
);
    reg [9:0] offset_x;
    reg [3:0] slow_down;
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin offset_x <= 0; slow_down <= 0; end 
        else begin
            slow_down <= slow_down + 1;
            if (slow_down == 4'd3) begin // Antes 8, ahora 3 (Mucho más rápido)
                slow_down <= 0;
                offset_x <= (offset_x == 639) ? 0 : offset_x + 1;
            end
        end
    end
    wire [9:0] world_x = (pix_x + offset_x) % 640;
    wire star_pattern = (world_x == 100 && pix_y == 50)  || (world_x == 300 && pix_y == 150) ||
                        (world_x == 500 && pix_y == 300) || (world_x == 150 && pix_y == 400) ||
                        (world_x == 450 && pix_y == 20)  || (world_x == 50  && pix_y == 450);
    assign bg_star_on = star_pattern;
endmodule

module stars (
    input  wire       clk, input  wire       rst_n, input  wire       s1_alive, input  wire       s2_alive,
    input  wire       v_sync, input  wire [9:0] pix_x, input  wire [9:0] pix_y,
    output wire       star_on
);
    reg [9:0] s1_x, s1_y, s2_x, s2_y;
    localparam STAR_SPEED = 10'd16; // Antes 12
    localparam STAR_SIZE  = 10'd16;
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin s1_x <= 10'd400; s1_y <= 10'd80; s2_x <= 10'd800; s2_y <= 10'd350; end
        else begin
            if (!s1_alive || s1_x < STAR_SPEED) begin s1_x <= 10'd700; s1_y <= (s1_y + 10'd123) % 10'd400; end else s1_x <= s1_x - STAR_SPEED;
            if (!s2_alive || s2_x < STAR_SPEED) begin s2_x <= 10'd900; s2_y <= (s2_y + 10'd211) % 10'd400; end else s2_x <= s2_x - STAR_SPEED;
        end
    end
    function draw_star_shape;
        input [9:0] px, py, sx, sy;
        integer dx, dy; reg [9:0] rx, ry;
        begin
            rx = px - sx; ry = py - sy;
            dx = (rx > 7) ? (rx - 7) : (7 - rx); dy = (ry > 7) ? (ry - 7) : (7 - ry);
            draw_star_shape = (dx + dy <= 7) ? 1'b1 : 1'b0;
        end
    endfunction
    wire s1_pixel = (pix_x >= s1_x && pix_x < s1_x + STAR_SIZE) && (pix_y >= s1_y && pix_y < s1_y + STAR_SIZE) && draw_star_shape(pix_x, pix_y, s1_x, s1_y);
    wire s2_pixel = (pix_x >= s2_x && pix_x < s2_x + STAR_SIZE) && (pix_y >= s2_y && pix_y < s2_y + STAR_SIZE) && draw_star_shape(pix_x, pix_y, s2_x, s2_y);
    assign star_on = (s1_pixel && s1_alive) || (s2_pixel && s2_alive);
endmodule

module ship (
    input  wire       clk, input  wire       rst_n, input  wire       v_sync,
    input  wire [9:0] pix_x, input  wire [9:0] pix_y,
    input  wire       move_up, input  wire       move_down,
    output wire [9:0] ship_y_out, output wire       ship_on
);
    reg [9:0] ship_y;
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) ship_y <= 240;
        else begin
            if (move_up && ship_y > 15)       ship_y <= ship_y - 20; // Antes 15
            else if (move_down && ship_y < 435) ship_y <= ship_y + 20;
        end
    end
    assign ship_y_out = ship_y;
    wire [9:0] lx = pix_x - 40;
    wire [9:0] ly = pix_y - ship_y;
    wire in_box = (pix_x >= 40 && pix_x < 72 && pix_y >= ship_y && pix_y < ship_y + 32);
    wire body   = (lx >= 4  && lx <= 24 && ly >= 12 && ly <= 20); 
    wire nose   = (lx >= 25 && lx <= 30 && ly >= 14 && ly <= 18); 
    wire cockpit = (lx >= 12 && lx <= 20 && ly >= 13 && ly <= 19); 
    wire wing_u = (lx >= 2  && lx <= 10 && ly >= 4  && ly <= 12); 
    wire wing_d = (lx >= 2  && lx <= 10 && ly >= 20 && ly <= 28); 
    wire tail   = (lx >= 0  && lx <= 4  && ly >= 8  && ly <= 24); 
    assign ship_on = in_box && (body || nose || cockpit || wing_u || wing_d || tail);
endmodule

module meteoritos (
    input  wire       clk, input  wire       rst_n, input  wire       v_sync,
    input  wire [9:0] pix_x, input  wire [9:0] pix_y,
    input  wire       m1_alive, input  wire       m2_alive, input  wire       m3_alive,
    input  wire [5:0] speed_in, input  wire [3:0] score, output wire       meteor_on
);
    reg [9:0] m1_x, m1_y, m2_x, m2_y, m3_x, m3_y;
    localparam SIZE  = 10'd30;
    localparam SPAWN_X1 = 10'd700; localparam SPAWN_X2 = 10'd780; localparam SPAWN_X3 = 10'd850;

    // --- Generador Pseudo-Aleatorio (LFSR de 16 bits) ---
    // Usamos esto para variar la posición Y
    reg [15:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) lfsr <= 16'hACE1;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Y aleatoria derivada del LFSR (Rango 30 a 400)
    wire [9:0] rand_y = 10'd30 + (lfsr[8:0] % 370);

    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin 
            m1_x <= SPAWN_X1; m1_y <= 10'd100; 
            m2_x <= SPAWN_X2; m2_y <= 10'd350; 
            m3_x <= SPAWN_X3; m3_y <= 10'd220; 
        end
        else begin
            // Meteorito 1
            if (!m1_alive || m1_x < speed_in) begin
                m1_x <= SPAWN_X1; 
                // Nueva posición Y aleatoria al "respawnear"
                m1_y <= rand_y; 
            end else m1_x <= m1_x - speed_in;

            // Meteorito 2
            if (!m2_alive || m2_x < speed_in) begin
                m2_x <= SPAWN_X2; 
                // Usamos diferentes bits del LFSR para que no sean iguales
                m2_y <= 10'd30 + (lfsr[15:7] % 370); 
            end else m2_x <= m2_x - speed_in;

            // Meteorito 3 (Solo si score >= 7)
            if (score >= 4'd7) begin 
                if (!m3_alive || m3_x < speed_in) begin
                    m3_x <= SPAWN_X3; 
                    m3_y <= 10'd30 + ({lfsr[3:0], lfsr[15:11]} % 370);
                end else m3_x <= m3_x - speed_in; 
            end else begin
                m3_x <= SPAWN_X3; 
            end
        end
    end

    function draw_rock;
        input [9:0] px, py, mx, my;
        integer dx, dy; reg [9:0] rx, ry;
        begin
            rx = px - mx; ry = py - my;
            if ((rx + ry < 8) || (rx + (30-ry) < 8) || ((30-rx) + ry < 8) || ((30-rx) + (30-ry) < 8)) draw_rock = 0;
            else begin
                dx = rx - 15; dy = ry - 15; if ((dx*dx + dy*dy) < 16) draw_rock = 0;
                else begin dx = rx - 8; dy = ry - 8; if ((dx*dx + dy*dy) < 4) draw_rock = 0;
                else begin dx = rx - 22; dy = ry - 20; if ((dx*dx + dy*dy) < 9) draw_rock = 0; else draw_rock = 1; end end
            end
        end
    endfunction
    wire m1_p = (pix_x >= m1_x && pix_x < m1_x + SIZE) && (pix_y >= m1_y && pix_y < m1_y + SIZE) && draw_rock(pix_x, pix_y, m1_x, m1_y);
    wire m2_p = (pix_x >= m2_x && pix_x < m2_x + SIZE) && (pix_y >= m2_y && pix_y < m2_y + SIZE) && draw_rock(pix_x, pix_y, m2_x, m2_y);
    wire m3_p = (pix_x >= m3_x && pix_x < m3_x + SIZE) && (pix_y >= m3_y && pix_y < m3_y + SIZE) && draw_rock(pix_x, pix_y, m3_x, m3_y);
    assign meteor_on = (m1_p && m1_alive) || (m2_p && m2_alive) || (m3_p && m3_alive && (score >= 4'd7));
endmodule

module bullet (
    input  wire       clk, input  wire       rst_n, input  wire       v_sync,
    input  wire [9:0] pix_x, input  wire [9:0] pix_y, input  wire       shoot,
    input  wire [9:0] ship_x, input  wire [9:0] ship_y,
    output reg        bullet_active, output wire       bullet_on
);
    reg [9:0] b_x, b_y;
    localparam B_WIDTH  = 10'd12; localparam B_HEIGHT = 10'd3; localparam B_SPEED  = 10'd45; // Antes 30
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin bullet_active <= 1'b0; b_x <= 0; b_y <= 0; end
        else begin
            if (!bullet_active) begin
                if (shoot) begin bullet_active <= 1'b1; b_x <= ship_x + 25; b_y <= ship_y + 14; end
            end else begin
                if (b_x >= 10'd640) bullet_active <= 1'b0; else b_x <= b_x + B_SPEED;
            end
        end
    end
    assign bullet_on = bullet_active && (pix_x >= b_x && pix_x < b_x + B_WIDTH) && (pix_y >= b_y && pix_y < b_y + B_HEIGHT);
endmodule

module collisions (
    input  wire v_sync, input  wire rst_n,
    input  wire [9:0] ship_x, ship_y, m1_x, m1_y, m2_x, m2_y, m3_x, m3_y, s1_x, s1_y, s2_x, s2_y, b_x, b_y,
    input  wire bullet_active,
    output reg m1_alive, m2_alive, m3_alive, s1_alive, s2_alive, output reg [1:0] lives,
    output wire hit_blink
);
    localparam SHIP_SIZE = 10'd30; localparam MET_SIZE = 10'd30; localparam STAR_SIZE = 10'd16;
    localparam B_WIDTH = 10'd12; localparam B_HEIGHT = 10'd3;
    reg [5:0] hit_timer;
    assign hit_blink = (hit_timer > 0);
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin m1_alive<=1; m2_alive<=1; m3_alive<=1; s1_alive<=1; s2_alive<=1; lives<=2; hit_timer<=0; end
        else begin
            if (hit_timer > 0) hit_timer <= hit_timer - 1;
            if (bullet_active) begin
                if (m1_alive&&(b_x+B_WIDTH>m1_x)&&(b_x<m1_x+MET_SIZE)&&(b_y+B_HEIGHT>m1_y)&&(b_y<m1_y+MET_SIZE)) m1_alive<=0;
                if (m2_alive&&(b_x+B_WIDTH>m2_x)&&(b_x<m2_x+MET_SIZE)&&(b_y+B_HEIGHT>m2_y)&&(b_y<m2_y+MET_SIZE)) m2_alive<=0;
                if (m3_alive&&(b_x+B_WIDTH>m3_x)&&(b_x<m3_x+MET_SIZE)&&(b_y+B_HEIGHT>m3_y)&&(b_y<m3_y+MET_SIZE)) m3_alive<=0;
            end
            if (s1_alive&&(ship_x+SHIP_SIZE>s1_x)&&(ship_x<s1_x+STAR_SIZE)&&(ship_y+SHIP_SIZE>s1_y)&&(ship_y<s1_y+STAR_SIZE)) s1_alive<=0;
            if (s2_alive&&(ship_x+SHIP_SIZE>s2_x)&&(ship_x<s2_x+STAR_SIZE)&&(ship_y+SHIP_SIZE>s2_y)&&(ship_y<s2_y+STAR_SIZE)) s2_alive<=0;
            if (hit_timer==0 && lives>0) begin
                if ((m1_alive&&(ship_x+SHIP_SIZE>m1_x)&&(ship_x<m1_x+MET_SIZE)&&(ship_y+SHIP_SIZE>m1_y)&&(ship_y<m1_y+MET_SIZE)) ||
                    (m2_alive&&(ship_x+SHIP_SIZE>m2_x)&&(ship_x<m2_x+MET_SIZE)&&(ship_y+SHIP_SIZE>m2_y)&&(ship_y<m2_y+MET_SIZE)) ||
                    (m3_alive&&(ship_x+SHIP_SIZE>m3_x)&&(ship_x<m3_x+MET_SIZE)&&(ship_y+SHIP_SIZE>m3_y)&&(ship_y<m3_y+MET_SIZE))) begin
                    lives <= lives - 1; hit_timer <= 30;
                end
            end
            if (m1_x>=640||m1_x<5) m1_alive<=1; if (m2_x>=640||m2_x<5) m2_alive<=1; if (m3_x>=640||m3_x<5) m3_alive<=1;
            if (s1_x>=640) s1_alive<=1; if (s2_x>=640) s2_alive<=1;
        end
    end
endmodule

module hearts (
    input  wire [9:0] pix_x, input  wire [9:0] pix_y, input  wire [1:0] lives, output wire       heart_on
);
    localparam START_X = 10'd85; // Movido a la derecha para dar espacio al texto
    localparam START_Y = 10'd20; 
    localparam SPACING = 10'd25;
    localparam TEXT_X  = 10'd20; // Posición texto "LIVES"

    // --- DIBUJO DE CORAZÓN ---
    function draw_heart;
        input [9:0] px, py, hx, hy; reg [9:0] rx, ry;
        begin
            rx = px - hx; ry = py - hy;
            draw_heart = ((ry==0&&(rx==3||rx==4||rx==11||rx==12))||(ry==1&&(rx>=2&&rx<=5||rx>=10&&rx<=13))||(ry>=2&&ry<=4&&(rx>=1&&rx<=14))||(ry==5&&(rx>=2&&rx<=13))||(ry==6&&(rx>=3&&rx<=12))||(ry==7&&(rx>=4&&rx<=11))||(ry==8&&(rx>=5&&rx<=10))||(ry==9&&(rx>=7&&rx<=8)));
        end
    endfunction

    // --- DIBUJO DE TEXTO (LIVES) ---
    // Usamos la misma escala 4x6 pero agrandada x2-x3 para igualar corazones
    function draw_char;
        input [23:0] char_code; input [9:0] px, py, ox, oy;
        reg [4:0] col, row;
        begin
            // Escalado simple x2 para que mida aprox 8x12 (cerca de corazón 16x10)
            col = (px - ox) >> 1; 
            row = (py - oy) >> 1;
            if (row < 6 && col < 4) draw_char = char_code[23 - (row * 4 + col)];
            else draw_char = 0;
        end
    endfunction
    
    wire [23:0] f_L = 24'b1000_1000_1000_1000_1000_1111;
    wire [23:0] f_I = 24'b0110_0010_0010_0010_0010_0110;
    wire [23:0] f_V = 24'b1001_1001_1001_1001_1001_0110;
    wire [23:0] f_E = 24'b1111_1000_1110_1000_1000_1111;
    wire [23:0] f_S = 24'b1111_1000_1110_0001_1001_1110;

    wire l_txt = (pix_x >= TEXT_X+0  && pix_x < TEXT_X+8)  && (pix_y >= START_Y && pix_y < START_Y+12) && draw_char(f_L, pix_x, pix_y, TEXT_X+0,  START_Y);
    wire i_txt = (pix_x >= TEXT_X+10 && pix_x < TEXT_X+18) && (pix_y >= START_Y && pix_y < START_Y+12) && draw_char(f_I, pix_x, pix_y, TEXT_X+10, START_Y);
    wire v_txt = (pix_x >= TEXT_X+20 && pix_x < TEXT_X+28) && (pix_y >= START_Y && pix_y < START_Y+12) && draw_char(f_V, pix_x, pix_y, TEXT_X+20, START_Y);
    wire e_txt = (pix_x >= TEXT_X+30 && pix_x < TEXT_X+38) && (pix_y >= START_Y && pix_y < START_Y+12) && draw_char(f_E, pix_x, pix_y, TEXT_X+30, START_Y);
    wire s_txt = (pix_x >= TEXT_X+40 && pix_x < TEXT_X+48) && (pix_y >= START_Y && pix_y < START_Y+12) && draw_char(f_S, pix_x, pix_y, TEXT_X+40, START_Y);

    wire text_pixel = l_txt || i_txt || v_txt || e_txt || s_txt;

    // --- CORAZONES ---
    wire h1 = (pix_x>=START_X && pix_x<START_X+16) && (pix_y>=START_Y && pix_y<START_Y+16) && draw_heart(pix_x, pix_y, START_X, START_Y);
    wire h2 = (pix_x>=START_X+SPACING && pix_x<START_X+SPACING+16) && (pix_y>=START_Y && pix_y<START_Y+16) && draw_heart(pix_x, pix_y, START_X+SPACING, START_Y);
    
    assign heart_on = text_pixel || (h1 && lives >= 2'd1) || (h2 && lives >= 2'd2);
endmodule

module numbers (
    input  wire [9:0] pix_x, input wire [9:0] pix_y, input wire [3:0] score, output wire number_on
);
    // Posición: Esquina inferior izquierda
    localparam X_POS = 10'd85; // Alineado con los corazones de arriba (aprox)
    localparam Y_POS = 10'd450; 
    localparam SIZE  = 10'd8;  // Reducido significativamente (Antes 20)
    
    // Posición del Texto SCORE
    localparam TEXT_X = 10'd20; 
    
    // --- DIBUJO DE TEXTO (SCORE) ---
    function draw_char;
        input [23:0] char_code; input [9:0] px, py, ox, oy;
        reg [4:0] col, row;
        begin
            col = (px - ox) >> 1; 
            row = (py - oy) >> 1;
            if (row < 6 && col < 4) draw_char = char_code[23 - (row * 4 + col)];
            else draw_char = 0;
        end
    endfunction

    wire [23:0] f_S = 24'b1111_1000_1110_0001_1001_1110;
    wire [23:0] f_C = 24'b0110_1001_1000_1000_1001_0110;
    wire [23:0] f_O = 24'b0110_1001_1001_1001_1001_0110;
    wire [23:0] f_R = 24'b1110_1001_1110_1100_1010_1001;
    wire [23:0] f_E = 24'b1111_1000_1110_1000_1000_1111;

    wire s_txt = (pix_x >= TEXT_X+0  && pix_x < TEXT_X+8)  && (pix_y >= Y_POS && pix_y < Y_POS+12) && draw_char(f_S, pix_x, pix_y, TEXT_X+0,  Y_POS);
    wire c_txt = (pix_x >= TEXT_X+10 && pix_x < TEXT_X+18) && (pix_y >= Y_POS && pix_y < Y_POS+12) && draw_char(f_C, pix_x, pix_y, TEXT_X+10, Y_POS);
    wire o_txt = (pix_x >= TEXT_X+20 && pix_x < TEXT_X+28) && (pix_y >= Y_POS && pix_y < Y_POS+12) && draw_char(f_O, pix_x, pix_y, TEXT_X+20, Y_POS);
    wire r_txt = (pix_x >= TEXT_X+30 && pix_x < TEXT_X+38) && (pix_y >= Y_POS && pix_y < Y_POS+12) && draw_char(f_R, pix_x, pix_y, TEXT_X+30, Y_POS);
    wire e_txt = (pix_x >= TEXT_X+40 && pix_x < TEXT_X+48) && (pix_y >= Y_POS && pix_y < Y_POS+12) && draw_char(f_E, pix_x, pix_y, TEXT_X+40, Y_POS);
    
    wire text_pixel = s_txt || c_txt || o_txt || r_txt || e_txt;

    // --- DIBUJO DE NÚMERO (7 Segmentos pequeño) ---
    wire [9:0] rel_x = pix_x - X_POS; wire [9:0] rel_y = pix_y - Y_POS;
    
    // Caja del número (escalada a SIZE)
    wire in_box = (pix_x>=X_POS && pix_x<X_POS+SIZE) && (pix_y>=Y_POS && pix_y<Y_POS+(SIZE*2));
    
    // Segmentos más finos para tamaño pequeño
    wire seg_a = (rel_y < 2); 
    wire seg_b = (rel_x >= SIZE-2 && rel_y < SIZE);
    wire seg_c = (rel_x >= SIZE-2 && rel_y >= SIZE); 
    wire seg_d = (rel_y >= (SIZE*2)-2);
    wire seg_e = (rel_x < 2 && rel_y >= SIZE); 
    wire seg_f = (rel_x < 2 && rel_y < SIZE); 
    wire seg_g = (rel_y >= SIZE-1 && rel_y <= SIZE+1);
    
    reg [6:0] s;
    always @(*) begin
        case(score) 0:s=126; 1:s=48; 2:s=109; 3:s=121; 4:s=51; 5:s=91; 6:s=95; 7:s=112; 8:s=127; 9:s=115; default:s=0; endcase
    end
    
    wire num_pixel = in_box && ((s[6]&&seg_a)||(s[5]&&seg_b)||(s[4]&&seg_c)||(s[3]&&seg_d)||(s[2]&&seg_e)||(s[1]&&seg_f)||(s[0]&&seg_g));

    assign number_on = text_pixel || num_pixel;
endmodule

module game_text (
    input  wire [9:0] pix_x, input  wire [9:0] pix_y,
    input  wire       show_menu, input  wire       show_end, input wire show_title, input wire show_restart, input wire show_won,
    output wire       pixel_on,  output wire       end_on,
    output wire       labels_on
);
    localparam LIVES_X = 10'd70;  localparam LIVES_Y = 10'd20;
    localparam SCORE_X = 10'd240; localparam SCORE_Y = 10'd450;
    localparam MENU_X  = 10'd240; localparam MENU_Y  = 10'd220;
    
    // Coordenadas Fin de Juego
    localparam END_X   = 10'd220; localparam END_Y   = 10'd200; // GAME OVER
    localparam REST_X  = 10'd240; localparam REST_Y  = 10'd260; // RESTART (Abajo)

    // Título "WORLD CLEAN"
    localparam TITLE_X = 10'd200; localparam TITLE_Y = 10'd150;

    function draw_char;
        input [23:0] char_code; input [9:0] px, py, ox, oy;
        reg [4:0] col, row;
        begin
            col = (px - ox) >> 2; row = (py - oy) >> 2;
            draw_char = char_code[23 - (row * 4 + col)];
        end
    endfunction

    // Fuentes 4x6
    wire [23:0] f_S = 24'b1111_1000_1110_0001_1001_1110;
    wire [23:0] f_C = 24'b0110_1001_1000_1000_1001_0110;
    wire [23:0] f_O = 24'b0110_1001_1001_1001_1001_0110;
    wire [23:0] f_R = 24'b1110_1001_1110_1100_1010_1001;
    wire [23:0] f_E = 24'b1111_1000_1110_1000_1000_1111;
    wire [23:0] f_L = 24'b1000_1000_1000_1000_1000_1111;
    wire [23:0] f_I = 24'b0110_0010_0010_0010_0010_0110;
    wire [23:0] f_V = 24'b1001_1001_1001_1001_1001_0110;
    wire [23:0] f_P = 24'b1110_1001_1110_1000_1000_1000;
    wire [23:0] f_A = 24'b0110_1001_1111_1001_1001_1001;
    wire [23:0] f_Y = 24'b1001_1001_0110_0010_0010_0010;
    wire [23:0] f_N = 24'b1001_1101_1011_1001_1001_1001;
    wire [23:0] f_W = 24'b1001_1001_1001_1011_1101_1001;
    wire [23:0] f_D = 24'b1110_1001_1001_1001_1001_1110;
    wire [23:0] f_G = 24'b0110_1001_1000_1011_1001_0110;
    wire [23:0] f_M = 24'b1001_1111_1111_1001_1001_1001;
    wire [23:0] f_M = 24'b1001_1111_1111_1001_1001_1001;
    wire [23:0] f_T = 24'b1110_0100_0100_0100_0100_0100;
    wire [23:0] f_U = 24'b1001_1001_1001_1001_1001_0110;


    // MENU: PLAY (Parpadeante)
    wire p_m = (pix_x>=MENU_X+0 && pix_x<MENU_X+16) && (pix_y>=MENU_Y && pix_y<MENU_Y+24) && draw_char(f_P, pix_x, pix_y, MENU_X+0, MENU_Y);
    wire l_m = (pix_x>=MENU_X+20 && pix_x<MENU_X+36) && (pix_y>=MENU_Y && pix_y<MENU_Y+24) && draw_char(f_L, pix_x, pix_y, MENU_X+20, MENU_Y);
    wire a_m = (pix_x>=MENU_X+40 && pix_x<MENU_X+56) && (pix_y>=MENU_Y && pix_y<MENU_Y+24) && draw_char(f_A, pix_x, pix_y, MENU_X+40, MENU_Y);
    wire y_m = (pix_x>=MENU_X+60 && pix_x<MENU_X+76) && (pix_y>=MENU_Y && pix_y<MENU_Y+24) && draw_char(f_Y, pix_x, pix_y, MENU_X+60, MENU_Y);
    
    // TITLE: "WORLD CLEAN" (Estático)
    wire w_t = (pix_x>=TITLE_X+0   && pix_x<TITLE_X+16)  && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_W, pix_x, pix_y, TITLE_X+0, TITLE_Y);
    wire o_t = (pix_x>=TITLE_X+20  && pix_x<TITLE_X+36)  && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_O, pix_x, pix_y, TITLE_X+20, TITLE_Y);
    wire r_t = (pix_x>=TITLE_X+40  && pix_x<TITLE_X+56)  && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_R, pix_x, pix_y, TITLE_X+40, TITLE_Y);
    wire l_t = (pix_x>=TITLE_X+60  && pix_x<TITLE_X+76)  && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_L, pix_x, pix_y, TITLE_X+60, TITLE_Y);
    wire d_t = (pix_x>=TITLE_X+80  && pix_x<TITLE_X+96)  && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_D, pix_x, pix_y, TITLE_X+80, TITLE_Y);
    
    wire c_t2= (pix_x>=TITLE_X+120 && pix_x<TITLE_X+136) && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_C, pix_x, pix_y, TITLE_X+120, TITLE_Y);
    wire l_t2= (pix_x>=TITLE_X+140 && pix_x<TITLE_X+156) && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_L, pix_x, pix_y, TITLE_X+140, TITLE_Y);
    wire e_t2= (pix_x>=TITLE_X+160 && pix_x<TITLE_X+176) && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_E, pix_x, pix_y, TITLE_X+160, TITLE_Y);
    wire a_t2= (pix_x>=TITLE_X+180 && pix_x<TITLE_X+196) && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_A, pix_x, pix_y, TITLE_X+180, TITLE_Y);
    wire n_t2= (pix_x>=TITLE_X+200 && pix_x<TITLE_X+216) && (pix_y>=TITLE_Y && pix_y<TITLE_Y+24) && draw_char(f_N, pix_x, pix_y, TITLE_X+200, TITLE_Y);

    wire title_pixels = show_title && (w_t || o_t || r_t || l_t || d_t || c_t2 || l_t2 || e_t2 || a_t2 || n_t2);

    assign pixel_on = (show_menu && (p_m || l_m || a_m || y_m)) || title_pixels;

    // END: "GAME OVER"
    // GAME
    wire g_go = (pix_x>=END_X+0  && pix_x<END_X+16) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_G, pix_x, pix_y, END_X+0,  END_Y);
    wire a_go = (pix_x>=END_X+20 && pix_x<END_X+36) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_A, pix_x, pix_y, END_X+20, END_Y);
    wire m_go = (pix_x>=END_X+40 && pix_x<END_X+56) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_M, pix_x, pix_y, END_X+40, END_Y);
    wire e_go = (pix_x>=END_X+60 && pix_x<END_X+76) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_E, pix_x, pix_y, END_X+60, END_Y);
    // OVER (Offset +100)
    wire o_e = (pix_x>=END_X+100 && pix_x<END_X+116) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_O, pix_x, pix_y, END_X+100, END_Y);
    wire v_e = (pix_x>=END_X+120 && pix_x<END_X+136) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_V, pix_x, pix_y, END_X+120, END_Y);
    wire e_e = (pix_x>=END_X+140 && pix_x<END_X+156) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_E, pix_x, pix_y, END_X+140, END_Y);
    wire r_e = (pix_x>=END_X+160 && pix_x<END_X+176) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_R, pix_x, pix_y, END_X+160, END_Y);
    
    // RESTART (Parpadeante)
    wire r_rs = (pix_x>=REST_X+0   && pix_x<REST_X+16)  && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_R, pix_x, pix_y, REST_X+0, REST_Y);
    wire e_rs = (pix_x>=REST_X+20  && pix_x<REST_X+36)  && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_E, pix_x, pix_y, REST_X+20, REST_Y);
    wire s_rs = (pix_x>=REST_X+40  && pix_x<REST_X+56)  && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_S, pix_x, pix_y, REST_X+40, REST_Y);
    wire t_rs = (pix_x>=REST_X+60  && pix_x<REST_X+76)  && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_T, pix_x, pix_y, REST_X+60, REST_Y);
    wire a_rs = (pix_x>=REST_X+80  && pix_x<REST_X+96)  && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_A, pix_x, pix_y, REST_X+80, REST_Y);
    wire r_rs2= (pix_x>=REST_X+100 && pix_x<REST_X+116) && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_R, pix_x, pix_y, REST_X+100, REST_Y);
    wire t_rs2= (pix_x>=REST_X+120 && pix_x<REST_X+136) && (pix_y>=REST_Y && pix_y<REST_Y+24) && draw_char(f_T, pix_x, pix_y, REST_X+120, REST_Y);

    // YOU WON (Si victoria)
    wire y_w = (pix_x>=END_X+0  && pix_x<END_X+16) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_Y, pix_x, pix_y, END_X+0,  END_Y);
    wire o_w = (pix_x>=END_X+20 && pix_x<END_X+36) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_O, pix_x, pix_y, END_X+20, END_Y);
    wire u_w = (pix_x>=END_X+40 && pix_x<END_X+56) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_U, pix_x, pix_y, END_X+40, END_Y);
    
    wire w_w = (pix_x>=END_X+80 && pix_x<END_X+96) && (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_W, pix_x, pix_y, END_X+80, END_Y);
    wire o_w2= (pix_x>=END_X+100&& pix_x<END_X+116)&& (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_O, pix_x, pix_y, END_X+100, END_Y);
    wire n_w = (pix_x>=END_X+120&& pix_x<END_X+136)&& (pix_y>=END_Y && pix_y<END_Y+24) && draw_char(f_N, pix_x, pix_y, END_X+120, END_Y);
    
    wire victory_msg = show_won && (y_w || o_w || u_w || w_w || o_w2 || n_w);
    wire gameover_msg = !show_won && ((g_go || a_go || m_go || e_go || o_e || v_e || e_e || r_e));

    assign end_on = (show_end && (victory_msg || gameover_msg)) || (show_restart && (r_rs || e_rs || s_rs || t_rs || a_rs || r_rs2 || t_rs2));
    
    assign labels_on = 0; 
endmodule

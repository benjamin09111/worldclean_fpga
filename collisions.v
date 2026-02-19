`default_nettype none

module collisions (
    input  wire       v_sync,
    input  wire       rst_n,
    // Posiciones
    input  wire [9:0] ship_x, ship_y,
    input  wire [9:0] m1_x, m1_y,
    input  wire [9:0] m2_x, m2_y,
    input  wire [9:0] m3_x, m3_y,
    input  wire [9:0] s1_x, s1_y,
    input  wire [9:0] s2_x, s2_y,
    input  wire [9:0] b_x, b_y,
    input  wire       bullet_active,
    // Estados de vida y puntos
    output reg        m1_alive, m2_alive, m3_alive,
    output reg        s1_alive, s2_alive,
    output reg [1:0]  lives // 2 bits para soportar hasta 3 vidas (usaremos 2)
);

    localparam SHIP_SIZE = 10'd30;
    localparam MET_SIZE  = 10'd30;
    localparam STAR_SIZE = 10'd16;
    localparam B_WIDTH   = 10'd12;
    localparam B_HEIGHT  = 10'd3;
    
    // Contador para evitar perder todas las vidas de golpe (Cooldown de choque)
    reg [5:0] hit_timer; 

    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            m1_alive <= 1'b1; m2_alive <= 1'b1; m3_alive <= 1'b1;
            s1_alive <= 1'b1; s2_alive <= 1'b1;
            lives    <= 2'd2; // Iniciamos con 2 vidas
            hit_timer <= 6'd0;
        end else begin
            
            // --- LÓGICA DE COOLDOWN ---
            if (hit_timer > 0) hit_timer <= hit_timer - 1'b1;

            // --- COLISIÓN BALA vs METEORITOS ---
            if (bullet_active) begin
                if (m1_alive && (b_x + B_WIDTH > m1_x) && (b_x < m1_x + MET_SIZE) &&
                    (b_y + B_HEIGHT > m1_y) && (b_y < m1_y + MET_SIZE))
                    m1_alive <= 1'b0;

                if (m2_alive && (b_x + B_WIDTH > m2_x) && (b_x < m2_x + MET_SIZE) &&
                    (b_y + B_HEIGHT > m2_y) && (b_y < m2_y + MET_SIZE))
                    m2_alive <= 1'b0;

                if (m3_alive && (b_x + B_WIDTH > m3_x) && (b_x < m3_x + MET_SIZE) &&
                    (b_y + B_HEIGHT > m3_y) && (b_y < m3_y + MET_SIZE))
                    m3_alive <= 1'b0;
            end

            // --- COLISIÓN NAVE vs ESTRELLAS ---
            if (s1_alive && (ship_x + SHIP_SIZE > s1_x) && (ship_x < s1_x + STAR_SIZE) &&
                (ship_y + SHIP_SIZE > s1_y) && (ship_y < s1_y + STAR_SIZE))
                s1_alive <= 1'b0;

            if (s2_alive && (ship_x + SHIP_SIZE > s2_x) && (ship_x < s2_x + STAR_SIZE) &&
                (ship_y + SHIP_SIZE > s2_y) && (ship_y < s2_y + STAR_SIZE))
                s2_alive <= 1'b0;

            // --- COLISIÓN NAVE vs METEORITOS (PERDER VIDA) ---
            if (hit_timer == 0 && lives > 0) begin
                if ((m1_alive && (ship_x + SHIP_SIZE > m1_x) && (ship_x < m1_x + MET_SIZE) && (ship_y + SHIP_SIZE > m1_y) && (ship_y < m1_y + MET_SIZE)) ||
                    (m2_alive && (ship_x + SHIP_SIZE > m2_x) && (ship_x < m2_x + MET_SIZE) && (ship_y + SHIP_SIZE > m2_y) && (ship_y < m2_y + MET_SIZE)) ||
                    (m3_alive && (ship_x + SHIP_SIZE > m3_x) && (ship_x < m3_x + MET_SIZE) && (ship_y + SHIP_SIZE > m3_y) && (ship_y < m3_y + MET_SIZE))) 
                begin
                    lives <= lives - 1'b1;
                    hit_timer <= 6'd30; // 30 frames de invulnerabilidad (0.5 seg a 60Hz)
                end
            end

            // --- REGENERACIÓN INTELIGENTE ---
            if (m1_x >= 10'd640 || m1_x < 10'd5) m1_alive <= 1'b1;
            if (m2_x >= 10'd640 || m2_x < 10'd5) m2_alive <= 1'b1;
            if (m3_x >= 10'd640 || m3_x < 10'd5) m3_alive <= 1'b1;
            
            if (s1_x >= 10'd640) s1_alive <= 1'b1;
            if (s2_x >= 10'd640) s2_alive <= 1'b1;
        end
    end
endmodule
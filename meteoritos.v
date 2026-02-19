`default_nettype none

module meteoritos (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       v_sync,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire       m1_alive,
    input  wire       m2_alive,
    input  wire       m3_alive,
    input  wire [4:0] speed_in,
    input  wire [3:0] score,
    output wire       meteor_on
);
    reg [9:0] m1_x, m1_y;
    reg [9:0] m2_x, m2_y;
    reg [9:0] m3_x, m3_y;

    localparam SIZE  = 10'd30;
    localparam SPAWN_X1 = 10'd700;
    localparam SPAWN_X2 = 10'd900;
    localparam SPAWN_X3 = 10'd1000;

    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            m1_x <= SPAWN_X1; m1_y <= 10'd100;
            m2_x <= SPAWN_X2; m2_y <= 10'd350;
            m3_x <= SPAWN_X3; m3_y <= 10'd220;
        end else begin
            if (!m1_alive) m1_x <= SPAWN_X1;
            else m1_x <= (m1_x < speed_in) ? SPAWN_X1 : m1_x - speed_in;

            if (!m2_alive) m2_x <= SPAWN_X2;
            else m2_x <= (m2_x < speed_in) ? SPAWN_X2 : m2_x - speed_in;

            if (score >= 4'd7) begin
                if (!m3_alive) m3_x <= SPAWN_X3;
                else m3_x <= (m3_x < speed_in) ? SPAWN_X3 : m3_x - speed_in;
            end else m3_x <= SPAWN_X3;
        end
    end

    // --- FUNCIÓN CORREGIDA (Sin usar **) ---
    function draw_rock;
        input [9:0] px, py, mx, my;
        integer dx, dy; // Usamos enteros para los cálculos de distancia
        reg [9:0] rx, ry;
        begin
            rx = px - mx;
            ry = py - my;
            
            // 1. Forma irregular
            if ((rx + ry < 8) || (rx + (30-ry) < 8) || ((30-rx) + ry < 8) || ((30-rx) + (30-ry) < 8))
                draw_rock = 0;
            else begin
                // Calculamos distancias para los cráteres manualmente
                // Cráter 1: Centro (15,15) Radio 4 (4*4 = 16)
                dx = rx - 15;
                dy = ry - 15;
                if ((dx*dx + dy*dy) < 16) draw_rock = 0;
                else begin
                    // Cráter 2: (8,8) Radio 2 (2*2 = 4)
                    dx = rx - 8;
                    dy = ry - 8;
                    if ((dx*dx + dy*dy) < 4) draw_rock = 0;
                    else begin
                        // Cráter 3: (22,20) Radio 3 (3*3 = 9)
                        dx = rx - 22;
                        dy = ry - 20;
                        if ((dx*dx + dy*dy) < 9) draw_rock = 0;
                        else draw_rock = 1;
                    end
                end
            end
        end
    endfunction

    wire m1_p = (pix_x >= m1_x && pix_x < m1_x + SIZE) && (pix_y >= m1_y && pix_y < m1_y + SIZE) && draw_rock(pix_x, pix_y, m1_x, m1_y);
    wire m2_p = (pix_x >= m2_x && pix_x < m2_x + SIZE) && (pix_y >= m2_y && pix_y < m2_y + SIZE) && draw_rock(pix_x, pix_y, m2_x, m2_y);
    wire m3_p = (pix_x >= m3_x && pix_x < m3_x + SIZE) && (pix_y >= m3_y && pix_y < m3_y + SIZE) && draw_rock(pix_x, pix_y, m3_x, m3_y);

    assign meteor_on = (m1_p && m1_alive) || (m2_p && m2_alive) || (m3_p && m3_alive && (score >= 4'd7));

endmodule
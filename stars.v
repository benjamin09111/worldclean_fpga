`default_nettype none

module stars (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       s1_alive,
    input  wire       s2_alive,
    input  wire       v_sync,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    output wire       star_on
);

    reg [9:0] s1_x, s1_y;
    reg [9:0] s2_x, s2_y;

    localparam STAR_SPEED = 10'd12;
    localparam STAR_SIZE  = 10'd16;

    // --- LÓGICA DE MOVIMIENTO ---
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            s1_x <= 10'd400; s1_y <= 10'd80;
            s2_x <= 10'd800; s2_y <= 10'd350;
        end else begin
            // Estrella 1
            if (!s1_alive || s1_x < STAR_SPEED) begin
                s1_x <= 10'd700;
                s1_y <= (s1_y + 10'd123) % 10'd400;
            end else begin
                s1_x <= s1_x - STAR_SPEED;
            end

            // Estrella 2
            if (!s2_alive || s2_x < STAR_SPEED) begin
                s2_x <= 10'd900;
                s2_y <= (s2_y + 10'd211) % 10'd400;
            end else begin
                s2_x <= s2_x - STAR_SPEED;
            end
        end
    end

    // --- FUNCIÓN DE DIBUJO ---
    function draw_star_shape;
        input [9:0] px, py, sx, sy;
        integer dx, dy; 
        reg [9:0] rx, ry;
        begin
            rx = px - sx;
            ry = py - sy;
            
            dx = (rx > 7) ? (rx - 7) : (7 - rx);
            dy = (ry > 7) ? (ry - 7) : (7 - ry);
            
            if (dx + dy <= 7) 
                draw_star_shape = 1'b1;
            else
                draw_star_shape = 1'b0;
        end
    endfunction

    wire s1_pixel = (pix_x >= s1_x && pix_x < s1_x + STAR_SIZE) && 
                    (pix_y >= s1_y && pix_y < s1_y + STAR_SIZE) && 
                    draw_star_shape(pix_x, pix_y, s1_x, s1_y);

    wire s2_pixel = (pix_x >= s2_x && pix_x < s2_x + STAR_SIZE) && 
                    (pix_y >= s2_y && pix_y < s2_y + STAR_SIZE) && 
                    draw_star_shape(pix_x, pix_y, s2_x, s2_y);

    assign star_on = (s1_pixel && s1_alive) || (s2_pixel && s2_alive);

endmodule
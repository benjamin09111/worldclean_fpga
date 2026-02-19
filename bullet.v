`default_nettype none

module bullet (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       v_sync,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire       shoot,
    input  wire [9:0] ship_x,
    input  wire [9:0] ship_y,
    output reg        bullet_active,
    output wire       bullet_on
);

    reg [9:0] b_x;
    reg [9:0] b_y;

    // --- AJUSTE DE FORMA RECTANGULAR ---
    localparam B_WIDTH  = 10'd12; // <--- Más largo (Horizontal)
    localparam B_HEIGHT = 10'd3;  // <--- Más delgado (Vertical)
    localparam B_SPEED  = 10'd30;  // Un poco más rápido

    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            bullet_active <= 1'b0;
            b_x <= 0;
            b_y <= 0;
        end else begin
            if (!bullet_active) begin
                if (shoot) begin
                    bullet_active <= 1'b1;
                    b_x <= ship_x + 25; 
                    b_y <= ship_y + 14; // Ajustado para que salga del centro
                end
            end else begin
                if (b_x >= 10'd640) begin
                    bullet_active <= 1'b0;
                end else begin
                    b_x <= b_x + B_SPEED;
                end
            end
        end
    end

    // Dibujo con dimensiones rectangulares
    assign bullet_on = bullet_active && 
                       (pix_x >= b_x && pix_x < b_x + B_WIDTH) &&
                       (pix_y >= b_y && pix_y < b_y + B_HEIGHT);

endmodule
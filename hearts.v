`default_nettype none

module hearts (
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire [1:0] lives, // Soporta hasta 3 vidas (0, 1, 2)
    output wire       heart_on
);
    // Posición inicial de los corazones (Esquina superior izquierda)
    localparam START_X = 10'd20;
    localparam START_Y = 10'd20;
    localparam SPACING = 10'd25; // Espacio entre corazones

    function draw_heart;
        input [9:0] px, py, hx, hy;
        reg [9:0] rx, ry;
        begin
            rx = px - hx;
            ry = py - hy;
            // Forma de corazón de 16x16
            draw_heart = (
                (ry == 0 && (rx == 3 || rx == 4 || rx == 11 || rx == 12)) ||
                (ry == 1 && (rx >= 2 && rx <= 5 || rx >= 10 && rx <= 13)) ||
                (ry >= 2 && ry <= 4 && (rx >= 1 && rx <= 14)) ||
                (ry == 5 && (rx >= 2 && rx <= 13)) ||
                (ry == 6 && (rx >= 3 && rx <= 12)) ||
                (ry == 7 && (rx >= 4 && rx <= 11)) ||
                (ry == 8 && (rx >= 5 && rx <= 10)) ||
                (ry == 9 && (rx >= 7 && rx <= 8))
            );
        end
    endfunction

    wire h1 = (pix_x >= START_X && pix_x < START_X + 16) && 
              (pix_y >= START_Y && pix_y < START_Y + 16) && draw_heart(pix_x, pix_y, START_X, START_Y);
              
    wire h2 = (pix_x >= START_X + SPACING && pix_x < START_X + SPACING + 16) && 
              (pix_y >= START_Y && pix_y < START_Y + 16) && draw_heart(pix_x, pix_y, START_X + SPACING, START_Y);

    // Se muestran según las vidas restantes
    assign heart_on = (h1 && lives >= 2'd1) || (h2 && lives >= 2'd2);

endmodule
// nexys_top.v
// Archivo Top para conectar el juego de TinyTapeout a la Nexys A7-100T

module nexys_top(
    input  wire        CLK100MHZ,    // Reloj interno de 100MHz (Pin E3)
    input  wire        CPU_RESETN,   // Botón de Reset (Pin C12) - Activo bajo
    input  wire        BTNU,         // Botón ARRIBA (Pin M18)
    input  wire        BTND,         // Botón ABAJO (Pin P18)
    input  wire        BTNC,         // Botón CENTRO / DISPARO (Pin N17)
    output wire [3:0]  VGA_R,        // Rojo VGA (4 bits)
    output wire [3:0]  VGA_G,        // Verde VGA (4 bits)
    output wire [3:0]  VGA_B,        // Azul VGA (4 bits)
    output wire        VGA_HS,       // Sync Horizontal
    output wire        VGA_VS        // Sync Vertical
);

    // --- 1. DIVISOR DE RELOJ (100MHz -> 25MHz) ---
    // El estándar VGA 640x480 usa un reloj de aprox 25.175 MHz. 
    // Dividir 100MHz por 4 es suficiente para que la mayoría de monitores enganchen.
    reg [1:0] clk_div = 2'b0;
    always @(posedge CLK100MHZ) begin
        clk_div <= clk_div + 1'b1;
    end
    wire clk_25mhz = clk_div[1];

    // --- 2. SEÑALES DE ENTRADA Y SALIDA ---
    wire [7:0] ui_in;
    wire [7:0] uo_out;
    
    // Mapeamos los botones a la interfaz ui_in de tu proyecto
    // ui_in[0] = move_up
    // ui_in[1] = move_down
    // ui_in[2] = shoot
    assign ui_in = {5'b0, BTNC, BTND, BTNU};

    // --- 3. INSTANCIA DE TU JUEGO ---
    tt_um_vga_example game_core (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(8'b0),     // No usados en este wrapper basico
        .uio_out(),
        .uio_oe(),
        .ena(1'b1),        // Siempre habilitado
        .clk(clk_25mhz),
        .rst_n(CPU_RESETN)
    );

    // --- 4. MAPEO DE SALIDA VGA (Adaptación de bits) ---
    // Tu proyecto entrega uo_out = {hsync, b, g, r, vsync, b, g, r}
    // uo_out[7] -> HSYNC
    // uo_out[3] -> VSYNC
    // uo_out[4] -> Rojo (R), uo_out[5] -> Verde (G), uo_out[6] -> Azul (B)
    
    assign VGA_HS = uo_out[7];
    assign VGA_VS = uo_out[3];
    
    // Como la Nexys tiene 4 bits por color, repetimos el bit de tu juego 
    // para que cuando esté encendido, se vea al máximo brillo (4'b1111).
    assign VGA_R = {4{uo_out[4]}};
    assign VGA_G = {4{uo_out[5]}};
    assign VGA_B = {4{uo_out[6]}};

endmodule

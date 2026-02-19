`default_nettype none

module meteor_manager (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       v_sync, // Para sincronizar la aparición
    input  wire       h_sync_active, // Para moverlos
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    output wire       any_meteor_on // 1 si cualquier píxel de meteorito está activo
);

    // Instancia del PRNG
    wire [15:0] random_value;
    prng my_prng (
        .clk(clk),
        .reset(~rst_n), // Reset del PRNG cuando el sistema se resetea
        .random_out(random_value)
    );

    // --- Configuración de Múltiples Meteoritos ---
    localparam NUM_METEORS = 2; // <--- Número de meteoritos simultáneos
    
    // Registros para cada meteorito
    reg [9:0] meteor_x_pos [NUM_METEORS-1:0];
    reg [9:0] meteor_y_pos [NUM_METEORS-1:0];
    reg [9:0] meteor_sizes [NUM_METEORS-1:0];
    reg       meteor_active[NUM_METEORS-1:0]; // Indica si el meteorito debe dibujarse

    // Contadores para espaciar la aparición de los meteoritos
    reg [7:0] spawn_delay_counter;
    localparam SPAWN_DELAY = 8'd60; // Retraso entre la aparición de meteoritos (frames)

    genvar i;
    generate
        for (i = 0; i < NUM_METEORS; i = i + 1) begin : meteor_gen
            wire meteor_i_on;
            wire meteor_i_passed_left;

            meteor single_meteor (
                .clk(clk),
                .rst_n(rst_n),
                .h_sync_active(h_sync_active),
                .pix_x(pix_x),
                .pix_y(pix_y),
                .start_x(meteor_x_pos[i]),
                .meteor_size(meteor_sizes[i]),
                .meteor_y(meteor_y_pos[i]),
                .meteor_on(meteor_i_on),
                .passed_screen_left(meteor_i_passed_left)
            );

            // Actualización y reinicio de meteoritos
            always @(posedge v_sync or negedge rst_n) begin
                if (~rst_n) begin
                    meteor_x_pos[i] <= 10'd640 + (i * 10'd100); // Espaciado inicial
                    meteor_y_pos[i] <= 10'd0; // Se recalcula al activar
                    meteor_sizes[i] <= 10'd0; // Se recalcula al activar
                    meteor_active[i] <= 1'b0;
                end else begin
                    // Reiniciar un meteorito cuando pasa la pantalla
                    if (meteor_i_passed_left && meteor_active[i]) begin
                        meteor_active[i] <= 1'b0; // Desactivar hasta que sea su turno
                        // No reiniciar aquí la posición X, el módulo meteor ya lo hará.
                    end

                    // Lógica para activar un nuevo meteorito después de un retraso
                    if (!meteor_active[i]) begin
                        if (spawn_delay_counter >= SPAWN_DELAY && random_value[0] == 1'b1) begin // Condición de "aleatoriedad" para el spawn
                            meteor_active[i] <= 1'b1;
                            meteor_x_pos[i] <= 10'd640 + random_value[15:10]; // Asegura que aparezca fuera de pantalla
                            meteor_y_pos[i] <= random_value[9:2]; // Y aleatorio (máx 255, min 0)
                            meteor_sizes[i] <= 10'd20 + (random_value[1:0] * 10'd10); // Tamaño entre 20 y 50
                            spawn_delay_counter <= 0; // Reiniciar retraso para el siguiente
                        end
                    end
                end
            end
        end
    endgenerate

    // Contador para el retraso de aparición
    always @(posedge v_sync or negedge rst_n) begin
        if (~rst_n) begin
            spawn_delay_counter <= 0;
        end else if (spawn_delay_counter < SPAWN_DELAY) begin
            spawn_delay_counter <= spawn_delay_counter + 1;
        end
    end

    // Combinar las señales de todos los meteoritos
    assign any_meteor_on = (meteor_gen[0].meteor_i_on && meteor_active[0]); // Siempre el primero
    // Sumar el resto si existen
    generate
        for (i = 1; i < NUM_METEORS; i = i + 1) begin : combine_meteors
            assign any_meteor_on = any_meteor_on || (meteor_gen[i].meteor_i_on && meteor_active[i]);
        end
    endgenerate

endmodule
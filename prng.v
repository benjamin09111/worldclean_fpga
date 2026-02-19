`default_nettype none

module prng (
    input wire clk,
    input wire reset, // Activo alto
    output reg [15:0] random_out // Salida aleatoria de 16 bits
);

    // Un simple LFSR de 16 bits
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            random_out <= 16'hAAAA; // Semilla inicial
        end else begin
            random_out <= {random_out[14:0], random_out[15] ^ random_out[12] ^ random_out[3] ^ random_out[0]};
        end
    end

endmodule
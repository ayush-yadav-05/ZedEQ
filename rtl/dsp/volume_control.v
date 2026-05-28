module volume_control #(
    parameter SAMPLE_W = 24,
    parameter GAIN_W = 32,
    parameter SHIFT = 28
) (
    input  wire clk,
    input  wire reset,
    input  wire sample_valid,
    input  wire signed [SAMPLE_W-1:0] sample_in,
    input  wire signed [GAIN_W-1:0] gain,
    input  wire mute,
    output reg  out_valid,
    output reg  signed [SAMPLE_W-1:0] sample_out
);
    reg signed [SAMPLE_W+GAIN_W-1:0] product;
    reg signed [SAMPLE_W+GAIN_W-1:0] scaled_r;
    wire signed [SAMPLE_W+GAIN_W-1:0] scaled;
    wire signed [SAMPLE_W-1:0] clipped;
    reg [2:0] valid_pipe;

    assign scaled = scaled_r;

    saturator #(
        .IN_W(SAMPLE_W + GAIN_W),
        .OUT_W(SAMPLE_W)
    ) u_sat (
        .in_sample(scaled),
        .out_sample(clipped)
    );

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            sample_out <= 0;
            product <= 0;
            scaled_r <= 0;
            valid_pipe <= 0;
        end else begin
            valid_pipe <= {valid_pipe[1:0], sample_valid};
            out_valid <= valid_pipe[2];
            if (sample_valid)
                product <= sample_in * gain;
            scaled_r <= product >>> SHIFT;
            if (valid_pipe[2])
                sample_out <= mute ? 0 : clipped;
        end
    end
endmodule

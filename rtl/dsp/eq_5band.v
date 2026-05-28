module eq_5band #(
    parameter SAMPLE_W = 24,
    parameter COEF_W = 32,
    parameter SHIFT = 28
) (
    input  wire clk,
    input  wire reset,
    input  wire clear,
    input  wire bypass,
    input  wire sample_valid,
    input  wire signed [SAMPLE_W-1:0] sample_in,
    input  wire [5*COEF_W-1:0] b0_bus,
    input  wire [5*COEF_W-1:0] b1_bus,
    input  wire [5*COEF_W-1:0] b2_bus,
    input  wire [5*COEF_W-1:0] a1_bus,
    input  wire [5*COEF_W-1:0] a2_bus,
    output reg  out_valid,
    output reg  signed [SAMPLE_W-1:0] sample_out
);
    wire v1, v2, v3, v4, v5;
    wire signed [SAMPLE_W-1:0] d1, d2, d3, d4, d5;

    biquad_iir #(.SAMPLE_W(SAMPLE_W), .COEF_W(COEF_W), .SHIFT(SHIFT)) u_bq0 (
        .clk(clk), .reset(reset), .clear(clear), .sample_valid(sample_valid), .sample_in(sample_in),
        .b0(b0_bus[0*COEF_W +: COEF_W]), .b1(b1_bus[0*COEF_W +: COEF_W]), .b2(b2_bus[0*COEF_W +: COEF_W]),
        .a1(a1_bus[0*COEF_W +: COEF_W]), .a2(a2_bus[0*COEF_W +: COEF_W]), .out_valid(v1), .sample_out(d1)
    );

    biquad_iir #(.SAMPLE_W(SAMPLE_W), .COEF_W(COEF_W), .SHIFT(SHIFT)) u_bq1 (
        .clk(clk), .reset(reset), .clear(clear), .sample_valid(v1), .sample_in(d1),
        .b0(b0_bus[1*COEF_W +: COEF_W]), .b1(b1_bus[1*COEF_W +: COEF_W]), .b2(b2_bus[1*COEF_W +: COEF_W]),
        .a1(a1_bus[1*COEF_W +: COEF_W]), .a2(a2_bus[1*COEF_W +: COEF_W]), .out_valid(v2), .sample_out(d2)
    );

    biquad_iir #(.SAMPLE_W(SAMPLE_W), .COEF_W(COEF_W), .SHIFT(SHIFT)) u_bq2 (
        .clk(clk), .reset(reset), .clear(clear), .sample_valid(v2), .sample_in(d2),
        .b0(b0_bus[2*COEF_W +: COEF_W]), .b1(b1_bus[2*COEF_W +: COEF_W]), .b2(b2_bus[2*COEF_W +: COEF_W]),
        .a1(a1_bus[2*COEF_W +: COEF_W]), .a2(a2_bus[2*COEF_W +: COEF_W]), .out_valid(v3), .sample_out(d3)
    );

    biquad_iir #(.SAMPLE_W(SAMPLE_W), .COEF_W(COEF_W), .SHIFT(SHIFT)) u_bq3 (
        .clk(clk), .reset(reset), .clear(clear), .sample_valid(v3), .sample_in(d3),
        .b0(b0_bus[3*COEF_W +: COEF_W]), .b1(b1_bus[3*COEF_W +: COEF_W]), .b2(b2_bus[3*COEF_W +: COEF_W]),
        .a1(a1_bus[3*COEF_W +: COEF_W]), .a2(a2_bus[3*COEF_W +: COEF_W]), .out_valid(v4), .sample_out(d4)
    );

    biquad_iir #(.SAMPLE_W(SAMPLE_W), .COEF_W(COEF_W), .SHIFT(SHIFT)) u_bq4 (
        .clk(clk), .reset(reset), .clear(clear), .sample_valid(v4), .sample_in(d4),
        .b0(b0_bus[4*COEF_W +: COEF_W]), .b1(b1_bus[4*COEF_W +: COEF_W]), .b2(b2_bus[4*COEF_W +: COEF_W]),
        .a1(a1_bus[4*COEF_W +: COEF_W]), .a2(a2_bus[4*COEF_W +: COEF_W]), .out_valid(v5), .sample_out(d5)
    );

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            sample_out <= 0;
        end else if (bypass) begin
            out_valid <= sample_valid;
            if (sample_valid)
                sample_out <= sample_in;
        end else begin
            out_valid <= v5;
            if (v5)
                sample_out <= d5;
        end
    end
endmodule

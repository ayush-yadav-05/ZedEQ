module audio_codec_if #(
    parameter SAMPLE_W = 24,
    parameter MCLK_HALF = 4,
    parameter BCLK_HALF = 16
) (
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire signed [SAMPLE_W-1:0] left_out_sample,
    input  wire signed [SAMPLE_W-1:0] right_out_sample,
    output wire sample_valid,
    output wire signed [SAMPLE_W-1:0] left_in_sample,
    output wire signed [SAMPLE_W-1:0] right_in_sample,
    output reg  mclk,
    output reg  bclk,
    output reg  lrclk,
    input  wire sdata_in,
    output wire sdata_out
);
    reg [7:0] mclk_cnt;
    reg [7:0] bclk_cnt;
    reg [5:0] bit_cnt;

    always @(posedge clk) begin
        if (reset || !enable) begin
            mclk <= 1'b0;
            bclk <= 1'b0;
            lrclk <= 1'b0;
            mclk_cnt <= 0;
            bclk_cnt <= 0;
            bit_cnt <= 0;
        end else begin
            if (mclk_cnt == MCLK_HALF-1) begin
                mclk <= ~mclk;
                mclk_cnt <= 0;
            end else
                mclk_cnt <= mclk_cnt + 1'b1;

            if (bclk_cnt == BCLK_HALF-1) begin
                bclk <= ~bclk;
                bclk_cnt <= 0;
                if (bclk) begin
                    if (bit_cnt == 6'd63)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 6'd31)
                        lrclk <= 1'b1;
                    else if (bit_cnt == 6'd63)
                        lrclk <= 1'b0;
                end
            end else
                bclk_cnt <= bclk_cnt + 1'b1;
        end
    end

    i2s_rx #(
        .SAMPLE_W(SAMPLE_W)
    ) u_rx (
        .clk(clk),
        .reset(reset || !enable),
        .bclk(bclk),
        .lrclk(lrclk),
        .sdata(sdata_in),
        .sample_valid(sample_valid),
        .left_sample(left_in_sample),
        .right_sample(right_in_sample)
    );

    i2s_tx #(
        .SAMPLE_W(SAMPLE_W)
    ) u_tx (
        .clk(clk),
        .reset(reset || !enable),
        .bclk(bclk),
        .lrclk(lrclk),
        .left_sample(left_out_sample),
        .right_sample(right_out_sample),
        .sdata(sdata_out)
    );
endmodule


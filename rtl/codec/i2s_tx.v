module i2s_tx #(
    parameter SAMPLE_W = 24
) (
    input  wire clk,
    input  wire reset,
    input  wire bclk,
    input  wire lrclk,
    input  wire signed [SAMPLE_W-1:0] left_sample,
    input  wire signed [SAMPLE_W-1:0] right_sample,
    output reg  sdata
);
    reg bclk_d;
    reg [5:0] bit_cnt;
    reg [SAMPLE_W-1:0] sh_l, sh_r;
    wire bclk_fall;

    assign bclk_fall = ~bclk & bclk_d;

    always @(posedge clk) begin
        if (reset) begin
            bclk_d <= 1'b0;
            bit_cnt <= 0;
            sh_l <= 0;
            sh_r <= 0;
            sdata <= 1'b0;
        end else begin
            bclk_d <= bclk;
            if (bclk_fall) begin
                if (bit_cnt == 6'd63) begin
                    bit_cnt <= 0;
                    sh_l <= left_sample;
                    sh_r <= right_sample;
                end else
                    bit_cnt <= bit_cnt + 1'b1;

                if (bit_cnt >= 0 && bit_cnt < SAMPLE_W) begin
                    sdata <= sh_l[SAMPLE_W-1];
                    sh_l <= {sh_l[SAMPLE_W-2:0], 1'b0};
                end else if (bit_cnt >= 32 && bit_cnt < 32+SAMPLE_W) begin
                    sdata <= sh_r[SAMPLE_W-1];
                    sh_r <= {sh_r[SAMPLE_W-2:0], 1'b0};
                end else
                    sdata <= 1'b0;
            end
        end
    end
endmodule


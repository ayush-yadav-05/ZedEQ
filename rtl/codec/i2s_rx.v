module i2s_rx #(
    parameter SAMPLE_W = 24
) (
    input  wire clk,
    input  wire reset,
    input  wire bclk,
    input  wire lrclk,
    input  wire sdata,
    output reg  sample_valid,
    output reg  signed [SAMPLE_W-1:0] left_sample,
    output reg  signed [SAMPLE_W-1:0] right_sample
);
    reg bclk_d;
    reg [5:0] bit_cnt;
    reg [SAMPLE_W-1:0] sh_l, sh_r;
    wire bclk_rise;

    assign bclk_rise = bclk & ~bclk_d;

    always @(posedge clk) begin
        if (reset) begin
            bclk_d <= 1'b0;
            bit_cnt <= 0;
            sh_l <= 0;
            sh_r <= 0;
            left_sample <= 0;
            right_sample <= 0;
            sample_valid <= 1'b0;
        end else begin
            bclk_d <= bclk;
            sample_valid <= 1'b0;
            if (bclk_rise) begin
                if (bit_cnt == 6'd63)
                    bit_cnt <= 0;
                else
                    bit_cnt <= bit_cnt + 1'b1;

                if (bit_cnt >= 1 && bit_cnt <= SAMPLE_W)
                    sh_l <= {sh_l[SAMPLE_W-2:0], sdata};
                else if (bit_cnt >= 33 && bit_cnt <= 32+SAMPLE_W)
                    sh_r <= {sh_r[SAMPLE_W-2:0], sdata};

                if (bit_cnt == 6'd63) begin
                    left_sample <= sh_l;
                    right_sample <= sh_r;
                    sample_valid <= 1'b1;
                end
            end
        end
    end
endmodule


module vu_meter #(
    parameter SAMPLE_W = 24,
    parameter DECAY = 18'h0100
) (
    input  wire clk,
    input  wire reset,
    input  wire sample_valid,
    input  wire signed [SAMPLE_W-1:0] left_sample,
    input  wire signed [SAMPLE_W-1:0] right_sample,
    output reg  [7:0] leds,
    output reg  [7:0] level
);
    reg [SAMPLE_W-1:0] mag_l, mag_r, mag, hold;

    always @(*) begin
        mag_l = left_sample[SAMPLE_W-1] ? (~left_sample + 1'b1) : left_sample;
        mag_r = right_sample[SAMPLE_W-1] ? (~right_sample + 1'b1) : right_sample;
        mag = (mag_l > mag_r) ? mag_l : mag_r;
    end

    always @(posedge clk) begin
        if (reset) begin
            hold <= 0;
            level <= 0;
            leds <= 8'h00;
        end else if (sample_valid) begin
            if (mag > hold)
                hold <= mag;
            else if (hold > DECAY)
                hold <= hold - DECAY;
            else
                hold <= 0;

            level <= hold[SAMPLE_W-2:SAMPLE_W-9];

            if (hold[SAMPLE_W-2:SAMPLE_W-4] >= 3'd7) leds <= 8'hFF;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd6) leds <= 8'h7F;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd5) leds <= 8'h3F;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd4) leds <= 8'h1F;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd3) leds <= 8'h0F;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd2) leds <= 8'h07;
            else if (hold[SAMPLE_W-2:SAMPLE_W-4] == 3'd1) leds <= 8'h03;
            else if (hold != 0) leds <= 8'h01;
            else leds <= 8'h00;
        end
    end
endmodule


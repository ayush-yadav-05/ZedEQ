module uart_tx #(
    parameter CLK_HZ = 100000000,
    parameter BAUD = 115200
) (
    input  wire clk,
    input  wire reset,
    input  wire [7:0] data,
    input  wire start,
    output reg  tx,
    output reg  busy
);
    localparam CLKS_PER_BIT = CLK_HZ / BAUD;

    reg [15:0] clk_cnt;
    reg [3:0] bit_idx;
    reg [9:0] shift;

    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1;
            busy <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
            shift <= 10'h3ff;
        end else begin
            if (!busy) begin
                tx <= 1'b1;
                clk_cnt <= 0;
                bit_idx <= 0;
                if (start) begin
                    shift <= {1'b1, data, 1'b0};
                    busy <= 1'b1;
                end
            end else begin
                tx <= shift[0];
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    shift <= {1'b1, shift[9:1]};
                    if (bit_idx == 4'd9)
                        busy <= 1'b0;
                    else
                        bit_idx <= bit_idx + 1'b1;
                end else
                    clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end
endmodule


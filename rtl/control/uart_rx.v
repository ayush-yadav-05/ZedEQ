module uart_rx #(
    parameter CLK_HZ = 100000000,
    parameter BAUD = 115200
) (
    input  wire clk,
    input  wire reset,
    input  wire rx,
    output reg  [7:0] data,
    output reg  valid
);
    localparam CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam HALF_BIT = CLKS_PER_BIT / 2;

    reg [15:0] clk_cnt;
    reg [3:0] bit_idx;
    reg [7:0] shift;
    reg [2:0] state;
    reg rx_d1, rx_d2;

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;

    always @(posedge clk) begin
        rx_d1 <= rx;
        rx_d2 <= rx_d1;
    end

    always @(posedge clk) begin
        if (reset) begin
            clk_cnt <= 0;
            bit_idx <= 0;
            shift <= 0;
            state <= S_IDLE;
            data <= 0;
            valid <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (!rx_d2)
                        state <= S_START;
                end
                S_START: begin
                    if (clk_cnt == HALF_BIT) begin
                        clk_cnt <= 0;
                        state <= rx_d2 ? S_IDLE : S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        shift[bit_idx] <= rx_d2;
                        if (bit_idx == 4'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        data <= shift;
                        valid <= rx_d2;
                        state <= S_IDLE;
                        clk_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


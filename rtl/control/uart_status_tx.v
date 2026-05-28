module uart_status_tx #(
    parameter CLK_HZ = 100000000,
    parameter RATE_HZ = 30
) (
    input  wire clk,
    input  wire reset,
    input  wire tx_busy,
    output reg  tx_start,
    output reg  [7:0] tx_data,
    input  wire [7:0] vu_level,
    input  wire bypass,
    input  wire mute,
    input  wire codec_ready
);
    localparam TICKS = CLK_HZ / RATE_HZ;

    reg [31:0] cnt;
    reg [2:0] pos;
    reg send;
    reg [7:0] flags;
    reg [7:0] chk;

    always @(*) begin
        flags = {5'b0, codec_ready, mute, bypass};
        chk = 8'h5A ^ vu_level ^ flags;
    end

    always @(posedge clk) begin
        if (reset) begin
            cnt <= 0;
            pos <= 0;
            send <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            tx_start <= 1'b0;

            if (cnt == TICKS-1) begin
                cnt <= 0;
                send <= 1'b1;
                pos <= 0;
            end else
                cnt <= cnt + 1'b1;

            if (send && !tx_busy && !tx_start) begin
                case (pos)
                    0: tx_data <= 8'h5A;
                    1: tx_data <= vu_level;
                    2: tx_data <= flags;
                    3: tx_data <= chk;
                    default: tx_data <= 8'h00;
                endcase
                tx_start <= 1'b1;
                if (pos == 3)
                    send <= 1'b0;
                else
                    pos <= pos + 1'b1;
            end
        end
    end
endmodule


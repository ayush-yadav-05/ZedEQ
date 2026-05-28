module uart_packet_parser (
    input  wire clk,
    input  wire reset,
    input  wire [7:0] rx_data,
    input  wire rx_valid,
    output reg  cmd_valid,
    output reg  [7:0] cmd,
    output reg  [7:0] index,
    output reg  [31:0] value
);
    reg [2:0] count;
    reg [7:0] pkt [0:7];
    reg [7:0] xsum;

    integer k;

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            cmd_valid <= 1'b0;
            cmd <= 0;
            index <= 0;
            value <= 0;
            for (k = 0; k < 8; k = k + 1)
                pkt[k] <= 0;
        end else begin
            cmd_valid <= 1'b0;
            if (rx_valid) begin
                if (count == 0) begin
                    if (rx_data == 8'hA5) begin
                        pkt[0] <= rx_data;
                        count <= 1;
                    end
                end else begin
                    pkt[count] <= rx_data;
                    if (count == 7) begin
                        xsum = pkt[0] ^ pkt[1] ^ pkt[2] ^ pkt[3] ^ pkt[4] ^ pkt[5] ^ pkt[6];
                        if (xsum == rx_data) begin
                            cmd <= pkt[1];
                            index <= pkt[2];
                            value <= {pkt[3], pkt[4], pkt[5], pkt[6]};
                            cmd_valid <= 1'b1;
                        end
                        count <= 0;
                    end else
                        count <= count + 1'b1;
                end
            end
        end
    end
endmodule

`timescale 1ns/1ps

module tb_uart_packet_parser;
    reg clk = 0;
    reg reset = 1;
    reg [7:0] rx_data = 0;
    reg rx_valid = 0;
    wire cmd_valid;
    wire [7:0] cmd;
    wire [7:0] index;
    wire [31:0] value;

    always #5 clk = ~clk;

    uart_packet_parser dut (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .cmd_valid(cmd_valid),
        .cmd(cmd),
        .index(index),
        .value(value)
    );

    initial begin
        #30 reset = 0;
        send_byte(8'hA5);
        send_byte(8'h01);
        send_byte(8'h03);
        send_byte(8'h12);
        send_byte(8'h34);
        send_byte(8'h56);
        send_byte(8'h78);
        send_byte(8'hA5 ^ 8'h01 ^ 8'h03 ^ 8'h12 ^ 8'h34 ^ 8'h56 ^ 8'h78);
        repeat (5) @(posedge clk);
        $finish;
    end

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            rx_data <= b;
            rx_valid <= 1'b1;
            @(posedge clk);
            rx_valid <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask
endmodule


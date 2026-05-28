`timescale 1ns/1ps

module tb_eq_5band;
    reg clk = 0;
    reg reset = 1;
    reg clear = 0;
    reg bypass = 0;
    reg valid = 0;
    reg signed [23:0] sample_in = 0;
    reg [159:0] b0_bus;
    reg [159:0] b1_bus;
    reg [159:0] b2_bus;
    reg [159:0] a1_bus;
    reg [159:0] a2_bus;
    wire out_valid;
    wire signed [23:0] sample_out;

    integer i;
    always #5 clk = ~clk;

    eq_5band dut (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .bypass(bypass),
        .sample_valid(valid),
        .sample_in(sample_in),
        .b0_bus(b0_bus),
        .b1_bus(b1_bus),
        .b2_bus(b2_bus),
        .a1_bus(a1_bus),
        .a2_bus(a2_bus),
        .out_valid(out_valid),
        .sample_out(sample_out)
    );

    initial begin
        b0_bus = 0;
        b1_bus = 0;
        b2_bus = 0;
        a1_bus = 0;
        a2_bus = 0;
        for (i = 0; i < 5; i = i + 1)
            b0_bus[i*32 +: 32] = 32'h10000000;
        #40 reset = 0;
        repeat (4) @(posedge clk);
        send_sample(24'sh010000);
        send_sample(24'sh020000);
        send_sample(24'sh030000);
        repeat (20) @(posedge clk);
        $finish;
    end

    task send_sample;
        input signed [23:0] s;
        begin
            @(posedge clk);
            sample_in <= s;
            valid <= 1'b1;
            @(posedge clk);
            valid <= 1'b0;
        end
    endtask
endmodule


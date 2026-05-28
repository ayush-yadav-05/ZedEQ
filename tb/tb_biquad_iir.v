`timescale 1ns/1ps

module tb_biquad_iir;
    reg clk = 0;
    reg reset = 1;
    reg clear = 0;
    reg valid = 0;
    reg signed [23:0] sample_in = 0;
    wire out_valid;
    wire signed [23:0] sample_out;

    always #5 clk = ~clk;

    biquad_iir dut (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .sample_valid(valid),
        .sample_in(sample_in),
        .b0(32'sh10000000),
        .b1(32'sh00000000),
        .b2(32'sh00000000),
        .a1(32'sh00000000),
        .a2(32'sh00000000),
        .out_valid(out_valid),
        .sample_out(sample_out)
    );

    initial begin
        #40 reset = 0;
        repeat (4) @(posedge clk);
        send_sample(24'sh100000);
        send_sample(-24'sh080000);
        send_sample(24'sh010000);
        repeat (10) @(posedge clk);
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
            sample_in <= 0;
            repeat (2) @(posedge clk);
        end
    endtask
endmodule


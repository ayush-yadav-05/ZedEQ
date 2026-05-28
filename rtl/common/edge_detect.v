module edge_detect (
    input  wire clk,
    input  wire reset,
    input  wire sig_in,
    output wire rise,
    output wire fall
);
    reg sig_d;

    always @(posedge clk) begin
        if (reset)
            sig_d <= 1'b0;
        else
            sig_d <= sig_in;
    end

    assign rise = sig_in & ~sig_d;
    assign fall = ~sig_in & sig_d;
endmodule


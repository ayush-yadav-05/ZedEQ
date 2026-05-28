module sync_reset (
    input  wire clk,
    input  wire reset_in,
    output wire reset_out
);
    reg [2:0] sr;

    always @(posedge clk or posedge reset_in) begin
        if (reset_in)
            sr <= 3'b111;
        else
            sr <= {sr[1:0], 1'b0};
    end

    assign reset_out = sr[2];
endmodule


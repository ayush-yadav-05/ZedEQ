module clock_reset (
    input  wire clk,
    input  wire reset_btn,
    output wire reset
);
    sync_reset u_sync_reset (
        .clk(clk),
        .reset_in(reset_btn),
        .reset_out(reset)
    );
endmodule


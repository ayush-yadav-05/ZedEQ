module eq_register_bank #(
    parameter COEF_W = 32
) (
    input  wire clk,
    input  wire reset,
    input  wire cmd_valid,
    input  wire [7:0] cmd,
    input  wire [7:0] index,
    input  wire [31:0] value,
    output reg  [5*COEF_W-1:0] b0_bus,
    output reg  [5*COEF_W-1:0] b1_bus,
    output reg  [5*COEF_W-1:0] b2_bus,
    output reg  [5*COEF_W-1:0] a1_bus,
    output reg  [5*COEF_W-1:0] a2_bus,
    output reg  [31:0] volume,
    output reg  bypass,
    output reg  mute,
    output reg  clear_filters
);
    localparam [31:0] ONE_Q28 = 32'sh10000000;

    integer i;
    reg [2:0] band;
    reg [2:0] coef;

    task set_flat;
        begin
            for (i = 0; i < 5; i = i + 1) begin
                b0_bus[i*COEF_W +: COEF_W] = ONE_Q28;
                b1_bus[i*COEF_W +: COEF_W] = 0;
                b2_bus[i*COEF_W +: COEF_W] = 0;
                a1_bus[i*COEF_W +: COEF_W] = 0;
                a2_bus[i*COEF_W +: COEF_W] = 0;
            end
            volume = ONE_Q28;
            bypass = 1'b0;
            mute = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            set_flat();
            clear_filters <= 1'b1;
        end else begin
            clear_filters <= 1'b0;
            if (cmd_valid) begin
                if (cmd == 8'h01 && index < 25) begin
                    band = index / 5;
                    coef = index - (band * 5);
                    case (coef)
                        0: b0_bus[band*COEF_W +: COEF_W] <= value;
                        1: b1_bus[band*COEF_W +: COEF_W] <= value;
                        2: b2_bus[band*COEF_W +: COEF_W] <= value;
                        3: a1_bus[band*COEF_W +: COEF_W] <= value;
                        4: a2_bus[band*COEF_W +: COEF_W] <= value;
                    endcase
                    clear_filters <= 1'b1;
                end else if (cmd == 8'h02) begin
                    volume <= value;
                end else if (cmd == 8'h03) begin
                    bypass <= value[0];
                    mute <= value[1];
                    clear_filters <= value[2];
                end else if (cmd == 8'h04) begin
                    set_flat();
                    clear_filters <= 1'b1;
                end
            end
        end
    end
endmodule


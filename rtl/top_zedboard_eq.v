module top_zedboard_eq (
    input  wire GCLK,
    input  wire BTNC,
    input  wire UART_RX,
    output wire UART_TX,
    inout  wire AC_SCL,
    inout  wire AC_SDA,
    output wire AC_ADR0,
    output wire AC_ADR1,
    output wire AC_MCLK,
    output wire AC_BCLK,
    output wire AC_LRCLK,
    input  wire AC_SDATA_I,
    output wire AC_SDATA_O,
    output wire [7:0] LED
);
    localparam SAMPLE_W = 24;
    localparam COEF_W = 32;

    wire reset;
    wire codec_ready;
    wire i2c_busy;
    wire i2c_ack_error;

    wire rx_valid;
    wire [7:0] rx_data;
    wire cmd_valid;
    wire [7:0] cmd;
    wire [7:0] index;
    wire [31:0] value;

    wire [5*COEF_W-1:0] b0_bus;
    wire [5*COEF_W-1:0] b1_bus;
    wire [5*COEF_W-1:0] b2_bus;
    wire [5*COEF_W-1:0] a1_bus;
    wire [5*COEF_W-1:0] a2_bus;
    wire [31:0] volume;
    wire bypass;
    wire mute;
    wire clear_filters;

    wire sample_valid;
    wire signed [SAMPLE_W-1:0] left_in;
    wire signed [SAMPLE_W-1:0] right_in;
    wire signed [SAMPLE_W-1:0] left_eq;
    wire signed [SAMPLE_W-1:0] right_eq;
    wire signed [SAMPLE_W-1:0] left_vol;
    wire signed [SAMPLE_W-1:0] right_vol;
    wire eq_l_valid;
    wire eq_r_valid;
    wire vol_l_valid;
    wire vol_r_valid;
    reg signed [SAMPLE_W-1:0] left_to_codec;
    reg signed [SAMPLE_W-1:0] right_to_codec;

    wire [7:0] vu_level;
    wire tx_busy;
    wire tx_start;
    wire [7:0] tx_data;

    assign AC_ADR0 = 1'b1;
    assign AC_ADR1 = 1'b1;

    clock_reset u_reset (
        .clk(GCLK),
        .reset_btn(BTNC),
        .reset(reset)
    );

    adau1761_config #(
        .CLK_HZ(100000000)
    ) u_codec_cfg (
        .clk(GCLK),
        .reset(reset),
        .ready(codec_ready),
        .i2c_busy(i2c_busy),
        .i2c_ack_error(i2c_ack_error),
        .scl(AC_SCL),
        .sda(AC_SDA)
    );

    audio_codec_if #(
        .SAMPLE_W(SAMPLE_W),
        .MCLK_HALF(4),
        .BCLK_HALF(16)
    ) u_audio (
        .clk(GCLK),
        .reset(reset),
        .enable(codec_ready),
        .left_out_sample(left_to_codec),
        .right_out_sample(right_to_codec),
        .sample_valid(sample_valid),
        .left_in_sample(left_in),
        .right_in_sample(right_in),
        .mclk(AC_MCLK),
        .bclk(AC_BCLK),
        .lrclk(AC_LRCLK),
        .sdata_in(AC_SDATA_I),
        .sdata_out(AC_SDATA_O)
    );

    uart_rx #(
        .CLK_HZ(100000000),
        .BAUD(115200)
    ) u_uart_rx (
        .clk(GCLK),
        .reset(reset),
        .rx(UART_RX),
        .data(rx_data),
        .valid(rx_valid)
    );

    uart_packet_parser u_parser (
        .clk(GCLK),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .cmd_valid(cmd_valid),
        .cmd(cmd),
        .index(index),
        .value(value)
    );

    eq_register_bank #(
        .COEF_W(COEF_W)
    ) u_regs (
        .clk(GCLK),
        .reset(reset),
        .cmd_valid(cmd_valid),
        .cmd(cmd),
        .index(index),
        .value(value),
        .b0_bus(b0_bus),
        .b1_bus(b1_bus),
        .b2_bus(b2_bus),
        .a1_bus(a1_bus),
        .a2_bus(a2_bus),
        .volume(volume),
        .bypass(bypass),
        .mute(mute),
        .clear_filters(clear_filters)
    );

    eq_5band #(
        .SAMPLE_W(SAMPLE_W),
        .COEF_W(COEF_W),
        .SHIFT(28)
    ) u_eq_l (
        .clk(GCLK),
        .reset(reset),
        .clear(clear_filters),
        .bypass(bypass),
        .sample_valid(sample_valid),
        .sample_in(left_in),
        .b0_bus(b0_bus),
        .b1_bus(b1_bus),
        .b2_bus(b2_bus),
        .a1_bus(a1_bus),
        .a2_bus(a2_bus),
        .out_valid(eq_l_valid),
        .sample_out(left_eq)
    );

    eq_5band #(
        .SAMPLE_W(SAMPLE_W),
        .COEF_W(COEF_W),
        .SHIFT(28)
    ) u_eq_r (
        .clk(GCLK),
        .reset(reset),
        .clear(clear_filters),
        .bypass(bypass),
        .sample_valid(sample_valid),
        .sample_in(right_in),
        .b0_bus(b0_bus),
        .b1_bus(b1_bus),
        .b2_bus(b2_bus),
        .a1_bus(a1_bus),
        .a2_bus(a2_bus),
        .out_valid(eq_r_valid),
        .sample_out(right_eq)
    );

    volume_control #(
        .SAMPLE_W(SAMPLE_W),
        .GAIN_W(32),
        .SHIFT(28)
    ) u_vol_l (
        .clk(GCLK),
        .reset(reset),
        .sample_valid(eq_l_valid),
        .sample_in(left_eq),
        .gain(volume),
        .mute(mute),
        .out_valid(vol_l_valid),
        .sample_out(left_vol)
    );

    volume_control #(
        .SAMPLE_W(SAMPLE_W),
        .GAIN_W(32),
        .SHIFT(28)
    ) u_vol_r (
        .clk(GCLK),
        .reset(reset),
        .sample_valid(eq_r_valid),
        .sample_in(right_eq),
        .gain(volume),
        .mute(mute),
        .out_valid(vol_r_valid),
        .sample_out(right_vol)
    );

    always @(posedge GCLK) begin
        if (reset) begin
            left_to_codec <= 0;
            right_to_codec <= 0;
        end else if (vol_l_valid && vol_r_valid) begin
            left_to_codec <= left_vol;
            right_to_codec <= right_vol;
        end
    end

    vu_meter #(
        .SAMPLE_W(SAMPLE_W)
    ) u_vu (
        .clk(GCLK),
        .reset(reset),
        .sample_valid(vol_l_valid && vol_r_valid),
        .left_sample(left_vol),
        .right_sample(right_vol),
        .leds(LED),
        .level(vu_level)
    );

    uart_status_tx #(
        .CLK_HZ(100000000),
        .RATE_HZ(30)
    ) u_status (
        .clk(GCLK),
        .reset(reset),
        .tx_busy(tx_busy),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .vu_level(vu_level),
        .bypass(bypass),
        .mute(mute),
        .codec_ready(codec_ready && !i2c_ack_error)
    );

    uart_tx #(
        .CLK_HZ(100000000),
        .BAUD(115200)
    ) u_uart_tx (
        .clk(GCLK),
        .reset(reset),
        .data(tx_data),
        .start(tx_start),
        .tx(UART_TX),
        .busy(tx_busy)
    );
endmodule

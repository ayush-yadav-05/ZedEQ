module adau1761_config #(
    parameter CLK_HZ = 100000000
) (
    input  wire clk,
    input  wire reset,
    output reg  ready,
    output wire i2c_busy,
    output wire i2c_ack_error,
    inout  wire scl,
    inout  wire sda
);
    localparam DEV_ADDR = 7'h3B;
    localparam DELAY_TICKS = CLK_HZ / 20;
    localparam NWRITES = 18;

    reg start_i2c;
    reg [15:0] reg_addr;
    reg [7:0] reg_data;
    reg [4:0] idx;
    reg [31:0] delay_cnt;
    reg [2:0] state;
    wire i2c_done;

    localparam S_WAIT  = 0;
    localparam S_LOAD  = 1;
    localparam S_START = 2;
    localparam S_BUSY  = 3;
    localparam S_NEXT  = 4;
    localparam S_READY = 5;

    i2c_master #(
        .CLK_HZ(CLK_HZ),
        .I2C_HZ(100000)
    ) u_i2c (
        .clk(clk),
        .reset(reset),
        .start(start_i2c),
        .dev_addr(DEV_ADDR),
        .reg_addr(reg_addr),
        .reg_data(reg_data),
        .busy(i2c_busy),
        .done(i2c_done),
        .ack_error(i2c_ack_error),
        .scl(scl),
        .sda(sda)
    );

    always @(*) begin
        reg_addr = 16'h4000;
        reg_data = 8'h00;
        case (idx)
            0:  begin reg_addr = 16'h4000; reg_data = 8'h01; end
            1:  begin reg_addr = 16'h4008; reg_data = 8'h00; end
            2:  begin reg_addr = 16'h4009; reg_data = 8'h00; end
            3:  begin reg_addr = 16'h400A; reg_data = 8'h01; end
            4:  begin reg_addr = 16'h400B; reg_data = 8'h05; end
            5:  begin reg_addr = 16'h400C; reg_data = 8'h01; end
            6:  begin reg_addr = 16'h400D; reg_data = 8'h05; end
            7:  begin reg_addr = 16'h4015; reg_data = 8'h00; end
            8:  begin reg_addr = 16'h4016; reg_data = 8'h00; end
            9:  begin reg_addr = 16'h4017; reg_data = 8'h00; end
            10: begin reg_addr = 16'h4019; reg_data = 8'h03; end
            11: begin reg_addr = 16'h401C; reg_data = 8'h21; end
            12: begin reg_addr = 16'h401E; reg_data = 8'h41; end
            13: begin reg_addr = 16'h4023; reg_data = 8'hE7; end
            14: begin reg_addr = 16'h4024; reg_data = 8'hE7; end
            15: begin reg_addr = 16'h4025; reg_data = 8'hE7; end
            16: begin reg_addr = 16'h4026; reg_data = 8'hE7; end
            17: begin reg_addr = 16'h4029; reg_data = 8'h03; end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            idx <= 0;
            ready <= 1'b0;
            start_i2c <= 1'b0;
            delay_cnt <= 0;
            state <= S_WAIT;
        end else begin
            start_i2c <= 1'b0;
            case (state)
                S_WAIT: begin
                    if (delay_cnt == DELAY_TICKS) begin
                        delay_cnt <= 0;
                        idx <= 0;
                        state <= S_LOAD;
                    end else
                        delay_cnt <= delay_cnt + 1'b1;
                end
                S_LOAD: state <= S_START;
                S_START: begin
                    start_i2c <= 1'b1;
                    state <= S_BUSY;
                end
                S_BUSY: begin
                    if (i2c_done)
                        state <= S_NEXT;
                end
                S_NEXT: begin
                    if (idx == NWRITES-1)
                        state <= S_READY;
                    else begin
                        idx <= idx + 1'b1;
                        state <= S_LOAD;
                    end
                end
                S_READY: begin
                    ready <= 1'b1;
                    state <= S_READY;
                end
            endcase
        end
    end
endmodule


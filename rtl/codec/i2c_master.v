module i2c_master #(
    parameter CLK_HZ = 100000000,
    parameter I2C_HZ = 100000
) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [6:0] dev_addr,
    input  wire [15:0] reg_addr,
    input  wire [7:0] reg_data,
    output reg  busy,
    output reg  done,
    output reg  ack_error,
    inout  wire scl,
    inout  wire sda
);
    localparam DIV = CLK_HZ / (I2C_HZ * 4);

    reg scl_oe;
    reg sda_oe;
    reg [15:0] div_cnt;
    reg tick;
    reg [5:0] state;
    reg [1:0] phase;
    reg [2:0] byte_idx;
    reg [3:0] bit_idx;
    reg [7:0] cur_byte;
    reg sda_sample;

    assign scl = scl_oe ? 1'b0 : 1'bz;
    assign sda = sda_oe ? 1'b0 : 1'bz;

    localparam ST_IDLE  = 0;
    localparam ST_START = 1;
    localparam ST_BIT   = 2;
    localparam ST_ACK   = 3;
    localparam ST_STOP1 = 4;
    localparam ST_STOP2 = 5;
    localparam ST_DONE  = 6;

    always @(posedge clk) begin
        if (reset) begin
            div_cnt <= 0;
            tick <= 1'b0;
        end else if (busy) begin
            if (div_cnt == DIV-1) begin
                div_cnt <= 0;
                tick <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1'b1;
                tick <= 1'b0;
            end
        end else begin
            div_cnt <= 0;
            tick <= 1'b0;
        end
    end

    always @(*) begin
        case (byte_idx)
            0: cur_byte = {dev_addr, 1'b0};
            1: cur_byte = reg_addr[15:8];
            2: cur_byte = reg_addr[7:0];
            3: cur_byte = reg_data;
            default: cur_byte = 8'h00;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            scl_oe <= 1'b0;
            sda_oe <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            ack_error <= 1'b0;
            state <= ST_IDLE;
            phase <= 0;
            byte_idx <= 0;
            bit_idx <= 0;
            sda_sample <= 1'b1;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    scl_oe <= 1'b0;
                    sda_oe <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        ack_error <= 1'b0;
                        phase <= 0;
                        byte_idx <= 0;
                        bit_idx <= 7;
                        state <= ST_START;
                    end
                end

                ST_START: if (tick) begin
                    case (phase)
                        0: begin scl_oe <= 1'b0; sda_oe <= 1'b0; phase <= 1; end
                        1: begin sda_oe <= 1'b1; phase <= 2; end
                        2: begin scl_oe <= 1'b1; phase <= 0; state <= ST_BIT; end
                    endcase
                end

                ST_BIT: if (tick) begin
                    case (phase)
                        0: begin
                            sda_oe <= ~cur_byte[bit_idx];
                            phase <= 1;
                        end
                        1: begin
                            scl_oe <= 1'b0;
                            phase <= 2;
                        end
                        2: begin
                            scl_oe <= 1'b1;
                            phase <= 3;
                        end
                        3: begin
                            if (bit_idx == 0) begin
                                phase <= 0;
                                state <= ST_ACK;
                            end else begin
                                bit_idx <= bit_idx - 1'b1;
                                phase <= 0;
                            end
                        end
                    endcase
                end

                ST_ACK: if (tick) begin
                    case (phase)
                        0: begin sda_oe <= 1'b0; phase <= 1; end
                        1: begin scl_oe <= 1'b0; phase <= 2; end
                        2: begin sda_sample <= sda; phase <= 3; end
                        3: begin
                            scl_oe <= 1'b1;
                            if (sda_sample)
                                ack_error <= 1'b1;
                            if (byte_idx == 3) begin
                                phase <= 0;
                                state <= ST_STOP1;
                            end else begin
                                byte_idx <= byte_idx + 1'b1;
                                bit_idx <= 7;
                                phase <= 0;
                                state <= ST_BIT;
                            end
                        end
                    endcase
                end

                ST_STOP1: if (tick) begin
                    scl_oe <= 1'b1;
                    sda_oe <= 1'b1;
                    state <= ST_STOP2;
                end

                ST_STOP2: if (tick) begin
                    scl_oe <= 1'b0;
                    sda_oe <= 1'b0;
                    state <= ST_DONE;
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule


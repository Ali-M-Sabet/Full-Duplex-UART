module uart_rx_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    input  wire [5:0] prescale,
    input  wire       par_en,
    input  wire [3:0] bit_cnt,
    input  wire [5:0] edge_cnt,
    input  wire       par_err,
    input  wire       strt_glitch,
    input  wire       stp_err,
    output wire       frame_start,
    output reg        enable,
    output reg        dat_samp_en,
    output wire       data_valid,
    output wire       par_chk_en,
    output wire       strt_chk_en,
    output wire       stp_chk_en,
    output wire       deser_en
);
    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP, REPORT} state_t;
    state_t state, next_state;
    wire last_edge = (edge_cnt == prescale - 6'd1);
    wire check_edge = (edge_cnt == prescale - 6'd2);

    assign frame_start = (state == IDLE) && !rx_in;
    assign deser_en = (state == DATA);
    assign strt_chk_en = (state == START) && check_edge;
    assign par_chk_en = (state == PARITY) && check_edge;
    assign stp_chk_en = (state == STOP) && (edge_cnt == prescale - 6'd3);
    assign data_valid = (state == REPORT) && !stp_err && (!par_en || !par_err);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (!rx_in) next_state = START;
            START: if (last_edge) next_state = strt_glitch ? IDLE : DATA;
            DATA: if (last_edge && bit_cnt == 4'd8)
                next_state = par_en ? PARITY : STOP;
            PARITY: if (last_edge) next_state = STOP;
            STOP: if (check_edge) next_state = REPORT;
            REPORT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        enable = 1'b0;
        dat_samp_en = 1'b0;
        case (state)
            IDLE: begin
                enable = !rx_in;
                dat_samp_en = !rx_in;
            end
            START, DATA, PARITY, STOP: begin
                enable = 1'b1;
                dat_samp_en = 1'b1;
            end
            default: begin
                enable = 1'b0;
                dat_samp_en = 1'b0;
            end
        endcase
    end
endmodule

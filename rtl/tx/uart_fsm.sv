module uart_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       data_valid,
    input  wire       par_en,
    input  wire       ser_done,
    output wire       ser_en,
    output reg  [1:0] mux_sel,
    output wire       busy
);
    localparam MUX_START  = 2'b00;
    localparam MUX_STOP   = 2'b01;
    localparam MUX_DATA   = 2'b10;
    localparam MUX_PARITY = 2'b11;

    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP} state_t;
    state_t state, next_state;

    assign busy = (state != IDLE);
    assign ser_en = (state == DATA) && !ser_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (data_valid) next_state = START;
            START: next_state = DATA;
            DATA: if (ser_done)
                next_state = par_en ? PARITY : STOP;
            PARITY: next_state = STOP;
            STOP: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        mux_sel = MUX_STOP;
        case (state)
            START: mux_sel = MUX_START;
            DATA: mux_sel = MUX_DATA;
            PARITY: mux_sel = MUX_PARITY;
            default: mux_sel = MUX_STOP;
        endcase
    end
endmodule

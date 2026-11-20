module uart_tx_top #(
    parameter DATA_WIDTH = 8
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] p_data,
    input  wire                  data_valid,
    input  wire                  par_en,
    input  wire                  par_typ,
    output reg                   tx_out,
    output wire                  busy
);
    localparam MUX_START  = 2'b00;
    localparam MUX_DATA   = 2'b10;
    localparam MUX_PARITY = 2'b11;

    reg frame_par_en;
    reg output_busy;
    reg mux_out;
    wire fsm_busy;
    wire ser_done;
    wire ser_en;
    wire ser_data;
    wire par_bit;
    wire [1:0] mux_sel;
    wire accept = data_valid && !busy;

    // Keep busy high until the registered pin has finished the stop bit.
    assign busy = fsm_busy || output_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_par_en <= 1'b0;
            output_busy <= 1'b0;
            tx_out <= 1'b1;
        end else begin
            if (accept)
                frame_par_en <= par_en;
            output_busy <= fsm_busy;
            tx_out <= mux_out;
        end
    end

    uart_serializer #(.DATA_WIDTH(DATA_WIDTH)) u_serializer (
        .clk(clk), .rst_n(rst_n), .p_data(p_data),
        .ser_en(ser_en), .data_valid(accept), .busy(busy),
        .ser_done(ser_done), .ser_data(ser_data)
    );

    uart_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .data_valid(accept),
        .par_en(frame_par_en), .ser_done(ser_done),
        .ser_en(ser_en), .mux_sel(mux_sel), .busy(fsm_busy)
    );

    uart_par_calc #(.DATA_WIDTH(DATA_WIDTH)) u_parity (
        .clk(clk), .rst_n(rst_n), .p_data(p_data),
        .data_valid(accept), .busy(busy), .par_typ(par_typ), .par_bit(par_bit)
    );

    always @(*) begin
        case (mux_sel)
            MUX_START: mux_out = 1'b0;
            MUX_DATA: mux_out = ser_data;
            MUX_PARITY: mux_out = par_bit;
            default: mux_out = 1'b1;
        endcase
    end
endmodule

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    input  wire [5:0] prescale,
    input  wire       par_en,
    input  wire       par_typ,
    output wire [7:0] p_data,
    output wire       data_valid,
    output wire       par_error,
    output wire       stp_error
);
    (* ASYNC_REG = "TRUE" *) reg rx_meta, rx_sync;
    reg [5:0] frame_prescale;
    reg frame_par_en, frame_par_typ;
    wire frame_start;
    wire [5:0] active_prescale = frame_start ? prescale : frame_prescale;
    wire [3:0] bit_cnt;
    wire [5:0] edge_cnt;
    wire enable, dat_samp_en, sampled_bit, deser_en;
    wire strt_chk_en, strt_glitch, par_chk_en, stp_chk_en;

    // Synchronize the serial input before using it in the receiver.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
            frame_prescale <= 6'd8;
            frame_par_en <= 1'b0;
            frame_par_typ <= 1'b0;
        end else begin
            rx_meta <= rx_in;
            rx_sync <= rx_meta;
            if (frame_start) begin
                frame_prescale <= prescale;
                frame_par_en <= par_en;
                frame_par_typ <= par_typ;
            end
        end
    end

    uart_rx_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .rx_in(rx_sync),
        .prescale(active_prescale), .par_en(frame_par_en),
        .bit_cnt(bit_cnt), .edge_cnt(edge_cnt),
        .par_err(par_error), .strt_glitch(strt_glitch), .stp_err(stp_error),
        .frame_start(frame_start), .enable(enable), .dat_samp_en(dat_samp_en),
        .data_valid(data_valid), .par_chk_en(par_chk_en),
        .strt_chk_en(strt_chk_en), .stp_chk_en(stp_chk_en), .deser_en(deser_en)
    );

    edge_bit_counter u_counter (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .prescale(active_prescale), .edge_cnt(edge_cnt), .bit_cnt(bit_cnt)
    );

    data_sampler u_sampler (
        .clk(clk), .rst_n(rst_n), .edge_cnt(edge_cnt),
        .prescale(active_prescale), .rx_in(rx_sync),
        .dat_samp_en(dat_samp_en), .sampled_bit(sampled_bit)
    );

    deserializer u_deserializer (
        .clk(clk), .rst_n(rst_n), .deser_en(deser_en),
        .edge_cnt(edge_cnt), .prescale(active_prescale),
        .sampled_bit(sampled_bit), .p_data(p_data)
    );

    strt_check u_start (
        .clk(clk), .rst_n(rst_n), .strt_chk_en(strt_chk_en),
        .sampled_bit(sampled_bit), .strt_glitch(strt_glitch)
    );

    par_check u_parity (
        .clk(clk), .rst_n(rst_n), .clear(frame_start),
        .par_typ(frame_par_typ), .par_chk_en(par_chk_en),
        .sampled_bit(sampled_bit), .p_data(p_data), .par_err(par_error)
    );

    stp_check u_stop (
        .clk(clk), .rst_n(rst_n), .clear(frame_start),
        .stp_chk_en(stp_chk_en), .sampled_bit(sampled_bit), .stp_err(stp_error)
    );
endmodule

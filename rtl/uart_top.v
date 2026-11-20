module uart_top (
    input  wire       tx_clk,
    input  wire       rx_clk,
    input  wire       rst_n,
    input  wire [5:0] prescale,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    input  wire       tx_par_en,
    input  wire       tx_par_typ,
    input  wire       rx_par_en,
    input  wire       rx_par_typ,
    input  wire       rx_in,
    output wire       tx_out,
    output wire       tx_busy,
    output wire [7:0] rx_data,
    output wire       rx_valid,
    output wire       rx_par_error,
    output wire       rx_stp_error
);
    uart_tx_top u_tx (
        .clk(tx_clk), .rst_n(rst_n), .p_data(tx_data), .data_valid(tx_valid),
        .par_en(tx_par_en), .par_typ(tx_par_typ), .tx_out(tx_out), .busy(tx_busy)
    );

    uart_rx u_rx (
        .clk(rx_clk), .rst_n(rst_n), .rx_in(rx_in), .prescale(prescale),
        .par_en(rx_par_en), .par_typ(rx_par_typ), .p_data(rx_data),
        .data_valid(rx_valid), .par_error(rx_par_error), .stp_error(rx_stp_error)
    );
endmodule

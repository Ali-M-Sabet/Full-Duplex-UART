`timescale 1ns/1ps

module tb_uart_top;
    parameter PRESCALE = 8;
    localparam [5:0] RX_PRESCALE = PRESCALE;
    reg tx_clk = 1'b0;
    reg rx_clk = 1'b0;
    reg b_tx_clk = 1'b0;
    reg b_rx_clk = 1'b0;
    reg rst_n = 1'b1;
    reg [7:0] a_data = 0;
    reg [7:0] b_data = 0;
    reg a_valid = 0;
    reg b_valid = 0;
    reg par_en = 0;
    reg par_typ = 0;
    reg b_par_en = 0;
    reg b_par_typ = 0;
    wire a_tx, b_tx, a_busy, b_busy;
    wire [7:0] a_rx_data, b_rx_data;
    wire a_rx_valid, b_rx_valid;
    wire a_par_error, a_stp_error, b_par_error, b_stp_error;
    integer a_received = 0;
    integer b_received = 0;
    integer a_sent = 0;
    integer b_sent = 0;
    integer mode;
    reg [7:0] a_expected [0:1023];
    reg [7:0] b_expected [0:1023];

    uart_top uart_a (
        .tx_clk(tx_clk), .rx_clk(rx_clk), .prescale(RX_PRESCALE),
        .rst_n(rst_n), .tx_data(a_data), .tx_valid(a_valid),
        .tx_par_en(par_en), .tx_par_typ(par_typ), .rx_par_en(b_par_en), .rx_par_typ(b_par_typ),
        .rx_in(b_tx), .tx_out(a_tx), .tx_busy(a_busy), .rx_data(a_rx_data),
        .rx_valid(a_rx_valid), .rx_par_error(a_par_error), .rx_stp_error(a_stp_error)
    );
    uart_top uart_b (
        .tx_clk(b_tx_clk), .rx_clk(b_rx_clk), .prescale(RX_PRESCALE),
        .rst_n(rst_n), .tx_data(b_data), .tx_valid(b_valid),
        .tx_par_en(b_par_en), .tx_par_typ(b_par_typ), .rx_par_en(par_en), .rx_par_typ(par_typ),
        .rx_in(a_tx), .tx_out(b_tx), .tx_busy(b_busy), .rx_data(b_rx_data),
        .rx_valid(b_rx_valid), .rx_par_error(b_par_error), .rx_stp_error(b_stp_error)
    );

    always #(5 * PRESCALE) tx_clk = ~tx_clk;
    always #5 rx_clk = ~rx_clk;
    initial begin
        #3;
        forever #(5 * PRESCALE) b_tx_clk = ~b_tx_clk;
    end
    initial begin
        #2;
        forever #5 b_rx_clk = ~b_rx_clk;
    end
    initial begin
        #10000000;
        $fatal(1, "Full-duplex test timed out");
    end

    always @(posedge rx_clk) begin
        if (rst_n && a_rx_valid) begin
            if (a_received >= b_sent || a_rx_data !== a_expected[a_received] ||
                a_par_error !== 1'b0 || a_stp_error !== 1'b0)
                $fatal(1, "UART A receive mismatch at byte %0d", a_received);
            a_received = a_received + 1;
        end
    end

    always @(posedge b_rx_clk) begin
        if (rst_n && b_rx_valid) begin
            if (b_received >= a_sent || b_rx_data !== b_expected[b_received] ||
                b_par_error !== 1'b0 || b_stp_error !== 1'b0)
                $fatal(1, "UART B receive mismatch at byte %0d", b_received);
            b_received = b_received + 1;
        end
    end

    task send_a;
        integer value;
        begin
            for (value = 0; value < 256; value = value + 1) begin
                wait (!a_busy);
                @(negedge tx_clk);
                a_data = value;
                b_expected[a_sent] = a_data;
                a_sent = a_sent + 1;
                a_valid = 1;
                @(negedge tx_clk);
                a_valid = 0;
            end
            wait (!a_busy);
        end
    endtask

    task send_b;
        integer value;
        begin
            repeat (2) @(negedge b_tx_clk);
            for (value = 0; value < 256; value = value + 1) begin
                wait (!b_busy);
                @(negedge b_tx_clk);
                b_data = 255 - value;
                a_expected[b_sent] = b_data;
                b_sent = b_sent + 1;
                b_valid = 1;
                @(negedge b_tx_clk);
                b_valid = 0;
            end
            wait (!b_busy);
        end
    endtask

    initial begin
        #2 rst_n = 0;
        repeat (3) @(negedge tx_clk);
        rst_n = 1;
        for (mode = 0; mode < 3; mode = mode + 1) begin
            par_en = mode != 0;
            par_typ = mode == 2;
            b_par_en = mode != 2;
            b_par_typ = mode == 1;
            fork
                send_a();
                send_b();
            join
            repeat (PRESCALE + 4) @(negedge rx_clk);
            if (a_received != b_sent || b_received != a_sent)
                $fatal(1, "Full-duplex test lost data");
        end
        $display("PASS: UART full duplex prescale=%0d, %0d bytes each way",
                 PRESCALE, a_received);
        $finish;
    end
endmodule

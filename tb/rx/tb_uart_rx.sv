`timescale 1ns/1ps

module tb_uart_rx;
    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg rx_in = 1'b1;
    reg [5:0] prescale = 8;
    reg par_en = 1'b0;
    reg par_typ = 1'b0;
    wire [7:0] p_data;
    wire data_valid, par_error, stp_error;
    reg [7:0] expected [0:4095];
    integer sent = 0;
    integer received = 0;
    integer value, mode, scale, phase;
    reg previous_valid = 1'b0;

    uart_rx dut (
        .clk(clk), .rst_n(rst_n), .rx_in(rx_in), .prescale(prescale),
        .par_en(par_en), .par_typ(par_typ), .p_data(p_data),
        .data_valid(data_valid), .par_error(par_error), .stp_error(stp_error)
    );

    always #5 clk = ~clk;
    initial begin
        #20000000;
        $fatal(1, "RX test timed out");
    end

    always @(posedge clk) begin
        if (!rst_n)
            previous_valid <= 1'b0;
        else begin
            if (data_valid) begin
                if (previous_valid || received >= sent)
                    $fatal(1, "RX unexpected or repeated valid pulse");
                if (p_data !== expected[received] || par_error !== 1'b0 || stp_error !== 1'b0)
                    $fatal(1, "RX mismatch at byte %0d: expected=%h got=%h parity=%b stop=%b",
                           received, expected[received], p_data, par_error, stp_error);
                received = received + 1;
            end
            previous_valid <= data_valid;
        end
    end

    task send_bit(input data, input noisy, input integer clocks);
        begin
            rx_in = data;
            if (noisy) begin
                #((clocks / 2 - 1) * 10);
                rx_in = !data;
                #10;
                rx_in = data;
                #((clocks - clocks / 2) * 10);
            end else
                #(clocks * 10);
        end
    endtask

    task send_frame(input [7:0] data, input bad_parity, input bad_stop, input noisy);
        integer bit_index;
        integer clocks;
        reg parity_enable, parity_type;
        begin
            clocks = prescale;
            parity_enable = par_en;
            parity_type = par_typ;
            if (!bad_parity && !bad_stop) begin
                expected[sent] = data;
                sent = sent + 1;
            end
            send_bit(1'b0, 1'b0, clocks);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                send_bit(data[bit_index], noisy, clocks);
            if (parity_enable)
                send_bit(($countones(data) % 2) ^ parity_type ^ bad_parity, noisy, clocks);
            send_bit(!bad_stop, noisy, clocks);
        end
    endtask

    task settle;
        begin
            rx_in = 1'b1;
            #((prescale + 4) * 10);
            if (received != sent)
                $fatal(1, "RX missing data: expected %0d bytes, received %0d", sent, received);
        end
    endtask

    initial begin
        #2 rst_n = 1'b0;
        #1;
        if (p_data !== 8'b0 || {data_valid, par_error, stp_error} !== 3'b000)
            $fatal(1, "RX reset failed");
        @(negedge clk);
        rst_n = 1'b1;
        #2;

        for (scale = 8; scale <= 32; scale = scale * 2) begin
            prescale = scale;
            for (mode = 0; mode < 3; mode = mode + 1) begin
                par_en = mode != 0;
                par_typ = mode == 2;
                for (value = 0; value < 256; value = value + 1)
                    send_frame(value, 1'b0, 1'b0, 1'b0);
                settle();
            end

            par_en = 1'b1;
            par_typ = 1'b0;
            send_frame(8'hA5, 1'b1, 1'b0, 1'b0);
            settle();
            if (par_error !== 1'b1)
                $fatal(1, "RX missed parity error");
            par_en = 1'b0;
            send_frame(8'h3C, 1'b0, 1'b0, 1'b0);
            settle();
            if (par_error !== 1'b0)
                $fatal(1, "RX retained parity error on a frame without parity");

            send_frame(8'h55, 1'b0, 1'b1, 1'b0);
            rx_in = 1'b1;
            #40;
            if (stp_error !== 1'b1)
                $fatal(1, "RX missed stop error");
            settle();
            send_frame(8'h96, 1'b0, 1'b0, 1'b0);
            settle();

            rx_in = 1'b0;
            #10;
            settle();
            par_en = 1'b1;
            send_frame(8'h69, 1'b0, 1'b0, 1'b1);
            settle();
        end

        prescale = 8;
        for (phase = 0; phase < 10; phase = phase + 1) begin
            #1;
            send_frame(8'hA6, 1'b0, 1'b0, 1'b0);
            settle();
        end

        par_en = 1'b1;
        par_typ = 1'b1;
        fork
            send_frame(8'hC5, 1'b0, 1'b0, 1'b0);
            begin
                #160;
                prescale = 32;
                par_en = 1'b0;
                par_typ = 1'b0;
            end
        join
        prescale = 8;
        settle();
        send_frame(8'hC6, 1'b0, 1'b0, 1'b0);
        settle();

        send_bit(1'b0, 1'b0, prescale);
        send_bit(1'b1, 1'b0, prescale);
        rst_n = 1'b0;
        rx_in = 1'b1;
        #2;
        if (p_data !== 8'b0 || {data_valid, par_error, stp_error} !== 3'b000)
            $fatal(1, "RX reset during a frame failed");
        #18 rst_n = 1'b1;
        settle();
        send_frame(8'h7E, 1'b0, 1'b0, 1'b0);
        settle();

        $display("PASS: UART RX, %0d frames", received);
        $finish;
    end
endmodule

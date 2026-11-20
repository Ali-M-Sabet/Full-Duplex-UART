`timescale 1ns/1ps

module tb_rx_blocks;
    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg enable = 1'b0;
    reg [5:0] prescale = 8;
    wire [5:0] counter_edge;
    wire [3:0] counter_bit;
    reg [5:0] edge_cnt = 0;
    reg rx_in = 0;
    reg sample_en = 0;
    wire sampled_bit;
    reg deser_en = 0;
    reg serial_data = 0;
    wire [7:0] p_data;
    wire [0:0] single_data;
    reg clear = 0;
    reg check_en = 0;
    reg par_typ = 0;
    reg check_bit = 0;
    reg [7:0] check_data = 0;
    wire par_err, stp_err, strt_glitch;
    integer scale, pattern, edge_index, bit_index, value, mode;
    reg expected_vote;

    edge_bit_counter u_counter (
        .clk(clk), .rst_n(rst_n), .enable(enable), .prescale(prescale),
        .edge_cnt(counter_edge), .bit_cnt(counter_bit)
    );
    data_sampler u_sampler (
        .clk(clk), .rst_n(rst_n), .edge_cnt(edge_cnt), .prescale(prescale),
        .rx_in(rx_in), .dat_samp_en(sample_en), .sampled_bit(sampled_bit)
    );
    deserializer u_deserializer (
        .clk(clk), .rst_n(rst_n), .deser_en(deser_en), .edge_cnt(edge_cnt),
        .prescale(prescale), .sampled_bit(serial_data), .p_data(p_data)
    );
    deserializer #(.DATA_WIDTH(1)) u_single (
        .clk(clk), .rst_n(rst_n), .deser_en(deser_en), .edge_cnt(edge_cnt),
        .prescale(prescale), .sampled_bit(serial_data), .p_data(single_data)
    );
    par_check u_parity (
        .clk(clk), .rst_n(rst_n), .clear(clear), .par_typ(par_typ),
        .par_chk_en(check_en), .sampled_bit(check_bit), .p_data(check_data), .par_err(par_err)
    );
    stp_check u_stop (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .stp_chk_en(check_en), .sampled_bit(check_bit), .stp_err(stp_err)
    );
    strt_check u_start (
        .clk(clk), .rst_n(rst_n), .strt_chk_en(check_en),
        .sampled_bit(check_bit), .strt_glitch(strt_glitch)
    );

    always #5 clk = ~clk;
    initial begin
        #2000000;
        $fatal(1, "RX block test timed out");
    end

    initial begin
        #2 rst_n = 0;
        @(negedge clk);
        if (counter_edge !== 0 || counter_bit !== 0 || p_data !== 0 ||
            single_data !== 0 || sampled_bit !== 0 || {par_err, stp_err, strt_glitch} !== 3'b000)
            $fatal(1, "RX block reset failed");
        rst_n = 1;

        for (scale = 8; scale <= 32; scale = scale * 2) begin
            prescale = scale;
            enable = 1;
            for (edge_index = 1; edge_index <= 12 * scale; edge_index = edge_index + 1) begin
                @(negedge clk);
                if (counter_edge !== edge_index % scale || counter_bit !== edge_index / scale)
                    $fatal(1, "RX counter mismatch");
            end
            enable = 0;
            @(negedge clk);
            if (counter_edge !== 0 || counter_bit !== 0)
                $fatal(1, "RX counter did not clear when disabled");

            for (pattern = 0; pattern < 8; pattern = pattern + 1) begin
                sample_en = 1;
                for (edge_index = 0; edge_index < scale; edge_index = edge_index + 1) begin
                    edge_cnt = edge_index;
                    rx_in = 0;
                    if (edge_index >= scale / 2 - 2 && edge_index <= scale / 2)
                        rx_in = (pattern >> (edge_index - (scale / 2 - 2))) & 1;
                    @(negedge clk);
                end
                expected_vote = $countones(pattern[2:0]) >= 2;
                if (sampled_bit !== expected_vote)
                    $fatal(1, "RX sampler mismatch: scale=%0d pattern=%b", scale, pattern[2:0]);
                sample_en = 0;
                @(negedge clk);
                if (sampled_bit !== 0)
                    $fatal(1, "RX sampler did not clear when disabled");
            end
        end

        prescale = 8;
        for (value = 0; value < 256; value = value + 1) begin
            deser_en = 1;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                serial_data = (value >> bit_index) & 1;
                for (edge_index = 0; edge_index < 8; edge_index = edge_index + 1) begin
                    edge_cnt = edge_index;
                    @(negedge clk);
                end
                if (single_data !== serial_data)
                    $fatal(1, "One-bit deserializer mismatch");
            end
            if (p_data !== value[7:0])
                $fatal(1, "Deserializer mismatch");
            deser_en = 0;
            serial_data = !serial_data;
            @(negedge clk);
            if (p_data !== value[7:0])
                $fatal(1, "Deserializer changed while disabled");
        end

        for (mode = 0; mode < 2; mode = mode + 1)
            for (value = 0; value < 256; value = value + 1) begin
                check_data = value;
                par_typ = mode;
                check_bit = ($countones(check_data) % 2) ^ par_typ;
                check_en = 1;
                @(negedge clk);
                if (par_err !== 0 || stp_err !== !check_bit || strt_glitch !== check_bit)
                    $fatal(1, "RX checker mismatch for valid parity");
                check_bit = !check_bit;
                @(negedge clk);
                if (par_err !== 1 || stp_err !== !check_bit || strt_glitch !== check_bit)
                    $fatal(1, "RX checker mismatch for invalid parity");
                check_en = 0;
                check_bit = !check_bit;
                @(negedge clk);
                if (par_err !== 1 || stp_err !== check_bit || strt_glitch !== !check_bit)
                    $fatal(1, "RX checkers failed to hold");
                clear = 1;
                @(negedge clk);
                if (par_err !== 0 || stp_err !== 0)
                    $fatal(1, "RX error clear failed");
                clear = 0;
            end

        $display("PASS: UART RX blocks");
        $finish;
    end
endmodule

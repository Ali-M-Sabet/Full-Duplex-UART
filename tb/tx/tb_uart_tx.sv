`timescale 1ns/1ps

module tb_uart_tx;
    parameter DATA_WIDTH = 8;
    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg [DATA_WIDTH-1:0] p_data = 0;
    reg data_valid = 1'b0;
    reg par_en = 1'b0;
    reg par_typ = 1'b0;
    wire tx_out, busy;
    integer value, mode;

    uart_tx_top #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .p_data(p_data), .data_valid(data_valid),
        .par_en(par_en), .par_typ(par_typ), .tx_out(tx_out), .busy(busy)
    );

    always #5 clk = ~clk;
    initial begin
        #10000000;
        $fatal(1, "TX test timed out");
    end

    task check_bit(input expected);
        begin
            if (tx_out !== expected || busy !== 1'b1)
                $fatal(1, "TX bit mismatch: data=%h mode=%0d expected=%b got=%b busy=%b",
                       value, mode, expected, tx_out, busy);
            @(posedge clk);
            #1;
        end
    endtask

    task send_and_check(input [DATA_WIDTH-1:0] data, input parity_en, input parity_type);
        integer bit_index;
        reg parity;
        begin
            parity = ($countones(data) % 2) ^ parity_type;
            @(negedge clk);
            p_data = data;
            par_en = parity_en;
            par_typ = parity_type;
            data_valid = 1'b1;
            @(posedge clk);
            #1;
            if (busy !== 1'b1)
                $fatal(1, "TX busy did not rise on acceptance");

            // Changing inputs while busy must not replace the accepted frame.
            @(negedge clk);
            p_data = ~data;
            par_en = !parity_en;
            par_typ = !parity_type;
            @(posedge clk);
            #1;
            check_bit(1'b0);
            for (bit_index = 0; bit_index < DATA_WIDTH; bit_index = bit_index + 1)
                check_bit(data[bit_index]);
            if (parity_en)
                check_bit(parity);
            check_bit(1'b1);
            data_valid = 1'b0;
            if (busy !== 1'b0 || tx_out !== 1'b1)
                $fatal(1, "TX did not return to idle after the full stop bit");
        end
    endtask

    initial begin
        #2 rst_n = 1'b0;
        #1;
        if (tx_out !== 1'b1 || busy !== 1'b0)
            $fatal(1, "TX reset failed");
        @(negedge clk);
        rst_n = 1'b1;
        for (mode = 0; mode < 3; mode = mode + 1)
            for (value = 0; value < (1 << DATA_WIDTH); value = value + 1)
                send_and_check(value, mode != 0, mode == 2);

        @(negedge clk);
        data_valid = 1'b1;
        repeat (4) @(negedge clk);
        rst_n = 1'b0;
        data_valid = 1'b0;
        #1;
        if (tx_out !== 1'b1 || busy !== 1'b0)
            $fatal(1, "TX reset during a frame failed");
        @(negedge clk);
        rst_n = 1'b1;
        send_and_check(8'hA5, 1'b1, 1'b0);
        $display("PASS: UART TX width=%0d", DATA_WIDTH);
        $finish;
    end
endmodule

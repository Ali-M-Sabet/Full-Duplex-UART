`timescale 1ns/1ps

module tb_uart_par_calc;
    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg [7:0] p_data = 8'b0;
    reg data_valid = 1'b0;
    reg busy = 1'b0;
    reg par_typ = 1'b0;
    wire par_bit;
    reg expected;
    integer value;
    integer mode;

    uart_par_calc dut (
        .clk(clk),
        .rst_n(rst_n),
        .p_data(p_data),
        .data_valid(data_valid),
        .busy(busy),
        .par_typ(par_typ),
        .par_bit(par_bit)
    );

    always #5 clk = ~clk;

    task check;
        input expected_bit;
        begin
            #1;
            if (par_bit !== expected_bit)
                $fatal(1, "Parity mismatch: data=%h type=%b expected=%b got=%b",
                       p_data, par_typ, expected_bit, par_bit);
        end
    endtask

    initial begin
        #2 rst_n = 1'b0;
        check(1'b0);
        @(negedge clk);
        rst_n = 1'b1;

        for (mode = 0; mode < 2; mode = mode + 1) begin
            for (value = 0; value < 256; value = value + 1) begin
                @(negedge clk);
                p_data = value;
                par_typ = mode;
                data_valid = 1'b1;
                busy = 1'b0;
                @(posedge clk);
                check(mode == 0 ? ($countones(p_data) % 2) :
                                  1 - ($countones(p_data) % 2));
            end
        end

        expected = par_bit;
        @(negedge clk);
        busy = 1'b1;
        p_data = 8'h01;
        @(posedge clk);
        check(expected);

        @(negedge clk);
        busy = 1'b0;
        data_valid = 1'b0;
        @(posedge clk);
        check(expected);

        @(negedge clk);
        data_valid = 1'b1;
        par_typ = 1'b0;
        @(posedge clk);
        check(1'b1);
        #1 rst_n = 1'b0;
        check(1'b0);

        $display("PASS: UART parity calculator");
        $finish;
    end
endmodule

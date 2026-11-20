module edge_bit_counter (
    input wire        clk,
    input wire        rst_n,

    input wire        enable,
    input wire [5:0]  prescale,

    output reg  [5:0] edge_cnt,
    output reg  [3:0] bit_cnt
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_cnt <= 6'd0;
            bit_cnt  <= 4'd0;
        end else if (!enable) begin
            edge_cnt <= 6'd0;
            bit_cnt  <= 4'd0;
        end else if (edge_cnt == (prescale - 6'd1)) begin
            edge_cnt <= 6'd0;
            bit_cnt  <= bit_cnt + 4'd1;
        end else begin
            edge_cnt <= edge_cnt + 6'd1;
        end
    end

endmodule

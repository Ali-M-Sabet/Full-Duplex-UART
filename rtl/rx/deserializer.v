module deserializer #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,

    input wire deser_en,
    input wire [5:0] edge_cnt,
    input wire [5:0] prescale,
    input wire sampled_bit,

    output reg [DATA_WIDTH-1:0] p_data
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_data <= {DATA_WIDTH{1'b0}};
        end else if (deser_en && (edge_cnt == (prescale - 6'd1))) begin
            p_data <= {sampled_bit, p_data} >> 1;
        end
    end

endmodule

module uart_par_calc #(
    parameter DATA_WIDTH = 8
) (
    input wire                  clk,
    input wire                  rst_n,
    input wire [DATA_WIDTH-1:0] p_data,
    input wire                  data_valid,
    input wire                  busy,
    input wire                  par_typ,
    output reg                  par_bit
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            par_bit <= 1'b0;
        end else if (data_valid && !busy) begin
            if (par_typ) begin
                par_bit <= ~^p_data;
            end else begin
                par_bit <= ^p_data;
            end
        end
    end
endmodule

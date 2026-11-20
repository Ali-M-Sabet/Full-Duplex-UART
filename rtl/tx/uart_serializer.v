module uart_serializer #(
    parameter DATA_WIDTH = 8
) (
    input wire                  clk,
    input wire                  rst_n,
    input wire [DATA_WIDTH-1:0] p_data,
    input wire                  ser_en,
    input wire                  data_valid,
    input wire                  busy,
    output wire                 ser_done,
    output wire                 ser_data
);
    localparam COUNT_WIDTH = (DATA_WIDTH <= 2) ? 1 : $clog2(DATA_WIDTH);
    localparam [COUNT_WIDTH-1:0] LAST_BIT = DATA_WIDTH - 1;

    reg [DATA_WIDTH-1:0]  data_reg;
    reg [COUNT_WIDTH-1:0] bit_count;

    assign ser_data = data_reg[0];
    assign ser_done = (bit_count == LAST_BIT);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg  <= {DATA_WIDTH{1'b0}};
            bit_count <= {COUNT_WIDTH{1'b0}};
        end else if (data_valid && !busy) begin
            data_reg  <= p_data;
            bit_count <= {COUNT_WIDTH{1'b0}};
        end else if (ser_en && !ser_done) begin
            data_reg  <= data_reg >> 1;
            bit_count <= bit_count + 1'b1;
        end
    end
endmodule

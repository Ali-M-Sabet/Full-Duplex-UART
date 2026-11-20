module data_sampler (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [5:0] edge_cnt,
    input  wire [5:0] prescale,
    input  wire       rx_in,
    input  wire       dat_samp_en,
    output wire       sampled_bit
);
    reg [2:0] samples;
    wire [5:0] middle = (prescale >> 1) - 6'd1;

    assign sampled_bit = (samples[0] & samples[1]) |
                         (samples[0] & samples[2]) |
                         (samples[1] & samples[2]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            samples <= 3'b000;
        else if (!dat_samp_en)
            samples <= 3'b000;
        else if (edge_cnt == middle - 6'd1)
            samples[0] <= rx_in;
        else if (edge_cnt == middle)
            samples[1] <= rx_in;
        else if (edge_cnt == middle + 6'd1)
            samples[2] <= rx_in;
    end
endmodule

module stp_check (
    input  wire clk,
    input  wire rst_n,
    input  wire clear,
    input  wire stp_chk_en,
    input  wire sampled_bit,
    output reg  stp_err
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stp_err <= 1'b0;
        else if (clear)
            stp_err <= 1'b0;
        else if (stp_chk_en)
            stp_err <= !sampled_bit;
    end
endmodule

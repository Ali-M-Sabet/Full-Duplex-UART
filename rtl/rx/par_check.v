module par_check (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clear,
    input  wire       par_typ,
    input  wire       par_chk_en,
    input  wire       sampled_bit,
    input  wire [7:0] p_data,
    output reg        par_err
);
    wire expected_parity = par_typ ? ~^p_data : ^p_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            par_err <= 1'b0;
        else if (clear)
            par_err <= 1'b0;
        else if (par_chk_en)
            par_err <= (sampled_bit != expected_parity);
    end
endmodule

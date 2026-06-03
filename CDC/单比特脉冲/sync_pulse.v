module sync_pulse(
    output wire dst_pulse,
    input wire src_pulse,
    input wire dclk,drst_n,
    input wire sclk,srst_n
);

    reg toggle;
    always @(posedge sclk or negedge srst_n) begin
        if (!srst_n) begin
            toggle <= 1'b0;
        end else if (src_pulse) begin
            toggle <= ~toggle;
        end
    end

    reg sync_ff1,sync_ff2,sync_ff3;
    always @(posedge dclk or negedge drst_n) begin
        if (!drst_n) begin
            {sync_ff1,sync_ff2,sync_ff3} <= 3'b0;
        end else begin
            sync_ff1 <= toggle;
            sync_ff2 <= sync_ff1;
            sync_ff3 <= sync_ff2;
        end
    end

    assign dst_pulse = sync_ff2 ^ sync_ff3;

endmodule
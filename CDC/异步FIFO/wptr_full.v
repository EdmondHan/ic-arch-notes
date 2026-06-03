module wptr_full #(
    parameter ADDRSIZE = 4
)(
    output reg wfull,
    output reg [ADDRSIZE:0]   wptr,
    output [ADDRSIZE-1:0] waddr,
    input  [ADDRSIZE:0]   wq2_rptr,
    input                 winc,wclk,wrst_n
);

    reg [ADDRSIZE:0] wbin;
    wire [ADDRSIZE:0] wptr_graynext,wptr_binnext;
    wire wfull_val;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            {wbin,wptr} <= '0;
        end else begin
            {wbin,wptr} <= {wptr_binnext, wptr_graynext};
        end
    end

    assign waddr = wbin[ADDRSIZE-1:0];
    assign wptr_binnext = wbin + (winc & ~wfull);
    assign wptr_graynext = (wptr_binnext>>1) ^ wptr_binnext;

    assign wfull_val = (wptr_graynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1],wq2_rptr[ADDRSIZE-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wfull <= 1'b0;
        end else begin
            wfull <= wfull_val;
        end
    end


endmodule
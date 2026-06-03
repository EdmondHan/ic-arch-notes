module rptr_empty #(
    parameter ADDRSIZE = 4
)(
    output reg rempty,
    output reg [ADDRSIZE:0] rptr,
    output [ADDRSIZE-1:0] raddr,
    input  [ADDRSIZE:0] rq2_wptr,
    input               rinc,rclk,rrst_n
);
    reg [ADDRSIZE:0] rptr_bin;
    wire [ADDRSIZE:0] rptr_graynext,rptr_binnext;
    wire rempty_val;
    
    always @(posedge rclk or negedge rrst_n)begin
        if(!rrst_n)begin
            {rptr_bin,rptr} <= '0;
        end
        else begin
           {rptr_bin,rptr} <= {rptr_binnext,rptr_graynext};
        end
    end

    assign raddr = rptr_bin[ADDRSIZE-1:0];
    assign rptr_binnext = rptr_bin + (rinc & ~rempty);
    assign rptr_graynext = (rptr_binnext>>1) ^ rptr_binnext;

    assign rempty_val = (rptr_graynext == rq2_wptr);

    always @(posedge rclk or negedge rrst_n)begin
        if(!rrst_n)begin
            rempty <= 1'b1;
        end
        else begin
            rempty <= rempty_val;
        end
    end

endmodule
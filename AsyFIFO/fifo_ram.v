module fifo_ram #(
    parameter DATASIZE = 8,
    parameter ADDRSIZE = 4
)(
    output [DATASIZE-1:0] rdata,
    input  [DATASIZE-1:0] wdata,
    input  [ADDRSIZE-1:0] waddr,raddr,
    input                 wclk,wen,wfull
);

    localparam DEPTH = 1 << ADDRSIZE;
    reg [DATASIZE-1:0] mem [DEPTH-1:0];

    assign rdata = mem[raddr];

    always @(posedge wclk) begin
        if (wen && !wfull) begin
            mem[waddr] <= wdata;
        end
    end




endmodule
module top_fifo #(
    parameter DATASIZE = 8,
    parameter ADDRSIZE = 4
)(
    output [DATASIZE-1:0]   rdata,
    output                  rempty,
    output                  wfull,
    input  [DATASIZE-1:0]   wdata,
    input                   winc,wclk,wrst_n,
    input                   rinc,rclk,rrst_n
);

    wire [ADDRSIZE-1:0] waddr,raddr;
    wire [ADDRSIZE:0]   wptr,rptr,wq2_rptr,rq2_wptr;
 
    fifo_ram #(
        .DATASIZE(DATASIZE),
        .ADDRSIZE(ADDRSIZE)
    ) u_fifo_ram (
        .rdata(rdata),
        .wdata(wdata),
        .waddr(waddr),
        .raddr(raddr),
        .wclk(wclk),
        .wen(winc),
        .wfull(wfull)
    );

    sync_r2w #(
        .ADDRSIZE(ADDRSIZE)
    ) u_sync_r2w (
        .wq2_rptr(wq2_rptr),
        .rptr(rptr),
        .wclk(wclk),
        .wrst_n(wrst_n)
    );

    sync_w2r #(
        .ADDRSIZE(ADDRSIZE)
    ) u_sync_w2r (
        .rq2_wptr(rq2_wptr),
        .wptr(wptr),
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    rptr_empty #(
        .ADDRSIZE(ADDRSIZE)
    ) u_rptr_empty (
        .rempty(rempty),
        .raddr(raddr),
        .rptr(rptr),
        .rq2_wptr(rq2_wptr),
        .rinc(rinc),
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    wptr_full #(
        .ADDRSIZE(ADDRSIZE)
    ) u_wptr_full (
        .wfull(wfull),
        .waddr(waddr),
        .wptr(wptr),
        .wq2_rptr(wq2_rptr),
        .winc(winc),
        .wclk(wclk),
        .wrst_n(wrst_n)
    );
    
endmodule
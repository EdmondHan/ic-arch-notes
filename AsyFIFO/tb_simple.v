`timescale 1ns/1ps

module tb_simple;
    localparam DATASIZE = 8;
    localparam ADDRSIZE = 4;

    reg  [DATASIZE-1:0] wdata;
    wire [DATASIZE-1:0] rdata;
    reg                 winc, rinc;
    wire                wfull, rempty;
    reg                 wclk, rclk, wrst_n, rrst_n;

    top_fifo #(.DATASIZE(DATASIZE), .ADDRSIZE(ADDRSIZE)) dut (
        .rdata(rdata), .rempty(rempty), .wfull(wfull),
        .wdata(wdata), .winc(winc), .wclk(wclk), .wrst_n(wrst_n),
        .rinc(rinc), .rclk(rclk), .rrst_n(rrst_n)
    );

    // 同一个时钟驱动读写（简化，先排除 CDC）
    initial begin wclk = 0; forever #5 wclk = ~wclk; end
    always @(*) rclk = wclk;   // 读写同时钟

    integer i;
    integer errors = 0;

    initial begin
        // 复位
        wrst_n = 0; rrst_n = 0; winc = 0; rinc = 0; wdata = 0;
        #20; wrst_n = 1; rrst_n = 1;
        @(posedge wclk);

        // ===== 阶段1：写满 16 个（值 0~15）=====
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge wclk);    // 在下降沿设置输入，避免竞争
            winc  = 1;
            wdata = i;
        end
        @(negedge wclk);
        winc = 0;
        $display("After writing: wfull=%b (expect 1)", wfull);

        // ===== 阶段2：读空 16 个，逐个对比 =====
        @(negedge wclk);
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge wclk);
            // 异步读：当前 rdata 就是队首
            if (rdata !== i[DATASIZE-1:0]) begin
                $display("ERROR: idx=%0d read=%h expect=%h", i, rdata, i);
                errors = errors + 1;
            end else begin
                $display("OK:    idx=%0d read=%h", i, rdata);
            end
            rinc = 1;   // 读走，下一拍指针前进
        end
        @(negedge wclk);
        rinc = 0;
        $display("After reading: rempty=%b (expect 1)", rempty);

        $display("=== errors=%0d ===", errors);
        if (errors == 0) $display("*** SIMPLE TEST PASSED ***");
        else $display("*** SIMPLE TEST FAILED ***");
        $finish;
    end

    initial begin #10000; $display("TIMEOUT"); $finish; end
endmodule
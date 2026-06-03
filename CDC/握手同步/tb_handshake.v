`timescale 1ns / 1ps

module tb_handshake;
    // ========== 参数 ==========
    localparam WIDTH = 8;
    localparam N_DATA = 100;

    // ========== 信号声明(集中在顶部)==========
    reg              sclk, srst_n;
    reg              src_valid;
    reg  [WIDTH-1:0] src_data;
    wire             src_ready;

    reg              dclk, drst_n;
    wire             dst_valid;
    wire [WIDTH-1:0] dst_data;

    integer          send_count = 0;
    integer          recv_count = 0;
    integer          err_count  = 0;
    integer          r_idx = 0;
    integer          w_idx = 0;
    integer          i;

    reg [WIDTH-1:0] data_list [0:N_DATA-1];

    // ========== 例化 DUT ==========
    sync_handshake #(.WIDTH(WIDTH)) inst0(
        .sclk(sclk), .srst_n(srst_n),
        .src_valid(src_valid), .src_data(src_data), .src_ready(src_ready),
        .dclk(dclk), .drst_n(drst_n),
        .dst_valid(dst_valid), .dst_data(dst_data)
    );

    // ========== 双时钟(互质频率)==========
    initial sclk = 0;
    always #14 sclk = ~sclk;   // 28ns 周期 ~36MHz

    initial dclk = 0;
    always #5  dclk = ~dclk;   // 10ns 周期 100MHz
    // 互质周期 28 vs 10 → 增加 CDC 测试覆盖

    // ========== 复位 + 初始化参考数据 ==========
    initial begin
        srst_n    = 0;
        drst_n    = 0;
        src_valid = 0;
        src_data  = 0;
        for (i = 0; i < N_DATA; i = i + 1)
            data_list[i] = i;
        #100;
        srst_n = 1;
        drst_n = 1;
        $display("[%0t] Reset released", $time);
    end

    // ========== 发送进程(严格单拍 valid)==========
    initial begin
        @(posedge srst_n);
        @(posedge sclk);
        while (w_idx < N_DATA) begin
            @(posedge sclk);
            if (src_ready) begin
                src_valid <= 1;
                src_data  <= data_list[w_idx];
                w_idx = w_idx + 1;
                @(posedge sclk);
                src_valid <= 0;
                // 等握手协议走完(src_ready 重新拉高)
            end
        end
        src_valid <= 0;
    end

    // ========== 计数:已成功发出的数据 ==========
    always @(posedge sclk) begin
        if (srst_n && src_valid && src_ready)
            send_count = send_count + 1;
    end

    // ========== 接收监控 + 自检 ==========
    always @(posedge dclk) begin
        if (drst_n && dst_valid) begin
            recv_count = recv_count + 1;
            if (dst_data !== data_list[r_idx]) begin
                $display("[%0t] ERROR: idx=%0d expect=%h got=%h",
                         $time, r_idx, data_list[r_idx], dst_data);
                err_count = err_count + 1;
            end
            r_idx = r_idx + 1;
        end
    end

    // ========== 结束判断 ==========
    initial begin
        @(posedge srst_n);
        // 等所有数据被接收(用 r_idx 跟踪)
        wait(r_idx >= N_DATA);
        #1000;   // 多等一会儿,确保没有意外的额外接收
        $display("===========================");
        $display("Sent: %0d   Received: %0d   Errors: %0d",
                 send_count, recv_count, err_count);
        if (send_count == N_DATA && recv_count == N_DATA && err_count == 0)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");
        $display("===========================");
        $finish;
    end

    // ========== 超时保护 ==========
    initial begin
        #500000;
        $display("[%0t] TIMEOUT! send=%0d recv=%0d", $time, send_count, recv_count);
        $finish;
    end

    // ========== 波形 ==========
    initial begin
        $dumpfile("handshake.vcd");
        $dumpvars(0, tb_handshake);
    end

endmodule
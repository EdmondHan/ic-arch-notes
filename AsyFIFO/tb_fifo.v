`timescale 1ns/1ps

module tb_fifo;

    // ===== 参数（和 DUT 一致）=====
    localparam DATASIZE = 8;
    localparam ADDRSIZE = 4;
    localparam DEPTH    = 1 << ADDRSIZE;   // 16

    // ===== 连接 DUT 的信号 =====
    reg  [DATASIZE-1:0] wdata;
    wire [DATASIZE-1:0] rdata;
    reg                 winc, rinc;
    wire                wfull, rempty;
    reg                 wclk, rclk;
    reg                 wrst_n, rrst_n;

    // ===== 例化 DUT =====
    top_fifo #(
        .DATASIZE(DATASIZE),
        .ADDRSIZE(ADDRSIZE)
    ) dut (
        .rdata  (rdata),
        .rempty (rempty),
        .wfull  (wfull),
        .wdata  (wdata),
        .winc   (winc),
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .rinc   (rinc),
        .rclk   (rclk),
        .rrst_n (rrst_n)
    );

    // ===== 产生两个互质频率的时钟 =====
    // wclk: 周期 7ns (约 143MHz)
    // rclk: 周期 13ns (约 77MHz)
    // 互质周期最大化暴露跨时钟域问题
    initial wclk = 0;
    always #3.5 wclk = ~wclk;   // 半周期 3.5ns

    initial rclk = 0;
    always #6.5 rclk = ~rclk;   // 半周期 6.5ns

    // ===== 参考模型：一个软件队列当"标准答案" =====
    // Verilog 的队列：用数组 + 头尾指针模拟
    reg [DATASIZE-1:0] ref_queue [0:1023];
    integer wr_idx = 0;   // 参考队列写指针
    integer rd_idx = 0;   // 参考队列读指针

    integer errors = 0;   // 错误计数
    integer num_written = 0;
    integer num_read = 0;

    // ===== 复位 =====
    initial begin
        wrst_n = 0;
        rrst_n = 0;
        winc = 0;
        rinc = 0;
        wdata = 0;
        #50;               // 保持复位 50ns
        wrst_n = 1;
        rrst_n = 1;
        $display("[%0t] Reset released", $time);
    end

    // ===== 写进程（修复版）=====
    reg [DATASIZE-1:0] wdata_cnt = 0;
    initial begin
        @(posedge wrst_n);
        @(posedge wclk);
        repeat (300) begin
            @(negedge wclk);        // 在下降沿驱动输入，避开时钟沿竞争
            if (!wfull) begin
                winc  = 1;
                wdata = wdata_cnt;
                // 在这一拍的下个上升沿，DUT 会真正写入 wdata_cnt
                // 所以这里同步记账是对齐的
                ref_queue[wr_idx] = wdata_cnt;
                wr_idx    = wr_idx + 1;
                wdata_cnt = wdata_cnt + 1;
                num_written = num_written + 1;
            end else begin
                winc = 0;
            end
        end
        winc = 0;
    end

    // ===== 读进程（修复版）=====
    initial begin
        @(posedge rrst_n);
        repeat (20) @(posedge rclk);   // 先攒数据
        repeat (400) begin
            @(negedge rclk);            // 下降沿采样，此时 rdata 已稳定
            if (!rempty) begin
                if (rdata !== ref_queue[rd_idx]) begin
                    $display("[%0t] ERROR: read=%h expected=%h (idx=%0d)",
                             $time, rdata, ref_queue[rd_idx], rd_idx);
                    errors = errors + 1;
                end
                rd_idx   = rd_idx + 1;
                num_read = num_read + 1;
                rinc = 1;       // 读走，下个上升沿指针前进
            end else begin
                rinc = 0;
            end
        end
        rinc = 0;
        #100;
        $display("=================================");
        $display("Written:%0d Read:%0d Errors:%0d", num_written, num_read, errors);
        if (errors == 0 && num_read > 0) $display("*** TEST PASSED ***");
        else $display("*** TEST FAILED ***");
        $finish;
    end


    // ===== 波形输出（保留）=====
    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, tb_fifo);
    end

    // ===== 文本监控：每个读时钟沿打印关键信号 =====
    always @(posedge rclk) begin
        if (rrst_n) begin   // 复位后才打印
            $display("[%0t] rclk^ | rinc=%b rempty=%b raddr=%0d rdata=%h rptr_bin=%0d | wbin=%0d wfull=%b rd_idx=%0d",
                     $time, rinc, rempty,
                     dut.u_rptr_empty.raddr,
                     rdata,
                     dut.u_rptr_empty.rptr_bin,
                     dut.u_wptr_full.wbin,
                     wfull,
                     rd_idx);
        end
    end

    // ===== 超时保护（防止死循环）=====
    initial begin
        #20000;
        $display("[%0t] TIMEOUT!", $time);
        $finish;
    end

endmodule
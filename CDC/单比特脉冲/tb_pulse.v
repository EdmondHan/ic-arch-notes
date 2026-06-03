`timescale 1ns/1ps

module tb_pulse;
    reg  src_pulse;
    reg  sclk, srst_n;
    reg  dclk, drst_n;
    wire dst_pulse;

    // ===== 例化 DUT =====
    sync_pulse uut (
        .dst_pulse(dst_pulse),
        .src_pulse(src_pulse),
        .sclk(sclk), .srst_n(srst_n),
        .dclk(dclk), .drst_n(drst_n)
    );

    // ===== 双时钟(源快目标慢,故意让脉冲难传)=====
    initial sclk = 0;
    always #2.5 sclk = ~sclk;    // 5ns 周期(200MHz),故意快

    initial dclk = 0;
    always #6.5 dclk = ~dclk;    // 13ns 周期(~77MHz),互质频率

    // ===== 计数器:统计发了多少、收到多少 =====
    integer src_count = 0;       // 源域发出的脉冲数
    integer dst_count = 0;       // 目标域收到的脉冲数

    // 在源时钟域数发了多少
    always @(posedge sclk) begin
        if (srst_n && src_pulse)
            src_count = src_count + 1;
    end

    // 在目标时钟域数收到多少
    always @(posedge dclk) begin
        if (drst_n && dst_pulse)
            dst_count = dst_count + 1;
    end

    // ===== 激励:在源时钟域同步发脉冲 =====
    integer i;
    initial begin
        // 复位
        srst_n = 0;
        drst_n = 0;
        src_pulse = 0;
        #50;
        srst_n = 1;
        drst_n = 1;

        // 等几个周期让同步器稳定
        repeat (5) @(posedge sclk);

        // 发 20 个脉冲,间隔足够大(>3 个目标时钟周期)
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge sclk);
            src_pulse = 1;        // 拉高 1 个源时钟周期
            @(posedge sclk);
            src_pulse = 0;        // 拉低
            // 等够目标域几个周期再发下一个(保证目标域能采到)
            repeat (5) @(posedge sclk);
        end

        // 最后再等一会儿,让最后几个脉冲在目标域传完
        repeat (30) @(posedge dclk);

        // ===== 自动判断 =====
        $display("=================================");
        $display("Source pulses sent:     %0d", src_count);
        $display("Destination pulses got: %0d", dst_count);
        if (src_count == dst_count) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED *** (lost %0d pulses)",
                     src_count - dst_count);
        end
        $display("=================================");
        $finish;
    end

    // 波形(可选)
    initial begin
        $dumpfile("pulse.vcd");
        $dumpvars(0, tb_pulse);
    end

    // 超时保护
    initial begin
        #100000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
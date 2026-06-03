module sync_handshake #(
    parameter WIDTH = 8
)(
    // ===== 源时钟域 =====
    input  wire             sclk,
    input  wire             srst_n,
    input  wire             src_valid,           // 源:我要发数据(单周期脉冲触发一次传输)
    input  wire [WIDTH-1:0] src_data,            // 源:要发的数据
    output wire             src_ready,           // 源:我空闲,可以接收新的 src_valid

    // ===== 目标时钟域 =====
    input  wire             dclk,
    input  wire             drst_n,
    output wire             dst_valid,           // 目标:数据到了(单周期脉冲)
    output reg [WIDTH-1:0]  dst_data             // 目标:接收到的数据
);

    reg [1:0] src_state, src_next_state;
    localparam S_IDLE = 2'd0,
               S_REQ  = 2'd1,
               S_WAIT = 2'd2;

    reg ack_sync1, ack_sync2;
    reg [WIDTH-1:0] src_data_reg;

    reg [1:0] dst_state, dst_next_state;
    localparam D_IDLE = 2'd0,
               D_GOT  = 2'd1,  
               D_ACK  = 2'd2;
    reg req_sync1, req_sync2;

    wire src_req = (src_state == S_REQ); // 源的请求信号，告诉目标有数据要发送   
    wire dst_ack = (dst_state == D_ACK); // 目标的 ACK 信号，告诉源数据已接收

    // ===== 源时钟域 FSM =====
    always @(*)begin
        case (src_state)
            S_IDLE: src_next_state = src_valid ? S_REQ : S_IDLE;
            S_REQ:  src_next_state = ack_sync2 ? S_WAIT : S_REQ;
            S_WAIT: src_next_state = !ack_sync2 ? S_IDLE : S_WAIT;
            default: src_next_state = S_IDLE;
        endcase
    end

    always @(posedge sclk or negedge srst_n)begin
        if (!srst_n) begin
            src_state <= S_IDLE;
        end else begin
            src_state <= src_next_state;
            if(src_state == S_IDLE && src_valid) begin
                src_data_reg <= src_data; // 存储要发送的数据
            end
            //两级同步器，消除亚稳态
            ack_sync1 <= dst_ack;
            ack_sync2 <= ack_sync1;
        end
    end

    assign src_ready = (src_state == S_IDLE);

    // ===== 目标时钟域 FSM =====
    always @(*)begin
        case (dst_state)
            D_IDLE: dst_next_state = req_sync2 ? D_GOT : D_IDLE;
            D_GOT:  dst_next_state = D_ACK; // 收到数据后立即进入 ACK 状态
            D_ACK:  dst_next_state = !req_sync2 ? D_IDLE : D_ACK; // 等待请求信号被清除
            default: dst_next_state = D_IDLE;
        endcase
    end

    always @(posedge dclk or negedge drst_n)begin
        if (!drst_n) begin
            dst_state <= D_IDLE;
        end else begin
            dst_state <= dst_next_state;
            //两级同步器，消除亚稳态
            req_sync1 <= src_req;
            req_sync2 <= req_sync1;
            if (dst_state == D_IDLE && req_sync2) begin
                dst_data <= src_data_reg; // 捕获数据
            end
        end
    end

    assign dst_valid = (dst_state == D_GOT);

endmodule

// 8N1 transmitter. Pulse `start` with `data` while !busy.
module uart_tx #(parameter CLKS = 234) (
    input clk, input start, input [7:0] data,
    output tx, output busy
);
    reg [9:0] sh = 10'h3ff;           // {stop, data, start}, LSB first
    reg [3:0] n = 0;                  // bits left
    reg [$clog2(CLKS)-1:0] c = 0;
    assign tx = sh[0];
    assign busy = n != 0;
    always @(posedge clk)
        if (!busy) begin
            if (start) begin sh <= {1'b1, data, 1'b0}; n <= 10; c <= CLKS-1; end
        end else if (c == 0) begin
            sh <= {1'b1, sh[9:1]}; n <= n - 1; c <= CLKS-1;
        end else c <= c - 1;
endmodule

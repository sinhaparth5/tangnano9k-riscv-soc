// 8N1 receiver, samples mid-bit. `valid` pulses 1 clk with `data`.
module uart_rx #(parameter CLKS = 234) (
    input clk, input rx, output reg valid = 0, output reg [7:0] data = 0
);
    reg [1:0] s = 2'b11;              // 2-FF synchronizer
    reg [3:0] n = 0;                  // 0 = idle, 1..9 = start+8 data bits sampled, 10 = stop
    reg [$clog2(CLKS)-1:0] c = 0;
    always @(posedge clk) begin
        s <= {s[0], rx};
        valid <= 0;
        if (n == 0) begin
            if (!s[1]) begin n <= 1; c <= CLKS/2 - 1; end   // falling edge: wait to mid start bit
        end else if (c != 0) c <= c - 1;
        else begin
            c <= CLKS - 1;
            if (n == 1) begin if (s[1]) n <= 0; else n <= 2; end   // false start -> idle
            else if (n <= 9) begin data <= {s[1], data[7:1]}; n <= n + 1; end
            else begin valid <= s[1]; n <= 0; end                  // stop bit must be 1
        end
    end
endmodule

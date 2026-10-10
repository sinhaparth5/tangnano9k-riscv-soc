// Phase 1: 27 MHz / 2^25 counter, top 6 bits drive the active-low LEDs.
module top(input clk, output [5:0] led);
    reg [24:0] cnt = 0;
    always @(posedge clk) cnt <= cnt + 1;
    assign led = ~cnt[24:19];
endmodule

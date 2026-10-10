// Phase 2: echo. LEDs show the last received byte (active-low).
module top(input clk, input uart_rx, output uart_tx, output [5:0] led);
    wire v; wire [7:0] d; wire busy;
    reg [7:0] last = 0;
    uart_rx rx(.clk(clk), .rx(uart_rx), .valid(v), .data(d));
    // ponytail: drops a byte if it arrives while tx is busy; fine for typing, add FIFO if pasting bulk
    uart_tx tx(.clk(clk), .start(v & ~busy), .data(d), .tx(uart_tx), .busy(busy));
    always @(posedge clk) if (v) last <= d;
    assign led = ~last[5:0];
endmodule

// Loopback: tx -> rx for several bytes, assert each comes back.
`timescale 1ns/1ps
module tb;
    reg clk = 0; always #18.5 clk = ~clk;          // ~27 MHz
    reg start = 0; reg [7:0] din; wire line, busy, v; wire [7:0] dout;
    uart_tx tx(.clk(clk), .start(start), .data(din), .tx(line), .busy(busy));
    uart_rx rx(.clk(clk), .rx(line), .valid(v), .data(dout));
    integer i; reg [7:0] exp [0:3];
    initial begin
        exp[0]=8'h55; exp[1]=8'hA3; exp[2]=8'h00; exp[3]=8'hFF;
        #1000;
        for (i=0;i<4;i=i+1) begin
            din = exp[i]; @(negedge clk); start = 1; @(negedge clk); start = 0;
            @(posedge v);
            if (dout !== exp[i]) begin $display("FAIL %h != %h", dout, exp[i]); $finish; end
            wait(!busy);
        end
        $display("PASS"); $finish;
    end
    initial begin #5_000_000 $display("FAIL timeout"); $finish; end
endmodule

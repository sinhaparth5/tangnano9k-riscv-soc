// Runs the real firmware, decodes the UART pin, expects the banner prompt.
`timescale 1ns/1ps
module tb;
    reg clk = 0; always #18.5 clk = ~clk;
    wire tx; wire [5:0] led; wire v; wire [7:0] d;
    top #(.HEX("build/fw.hex")) dut(.clk(clk), .uart_rx(1'b1), .uart_tx(tx), .led(led));
    uart_rx mon(.clk(clk), .rx(tx), .valid(v), .data(d));
    always @(posedge clk) if (v) begin
        $write("%c", d);
        if (d == ">") begin $display("\nPASS"); $finish; end
    end
    initial begin #30_000_000 $display("FAIL timeout"); $finish; end
endmodule

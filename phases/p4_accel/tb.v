// Runs the real firmware, decodes the UART pin, expects the banner prompt.
`timescale 1ns/1ps
module tb;
    reg clk = 0; always #18.5 clk = ~clk;
    wire tx, rxin; wire [5:0] led; wire v; wire [7:0] d;
    top #(.HEX("build/fw.hex")) dut(.clk(clk), .btn_s1(1'b1), .uart_rx(rxin), .uart_tx(tx), .led(led));
    uart_rx mon(.clk(clk), .rx(tx), .valid(v), .data(d));
    // type commands after each prompt, as a user would
    reg tstart = 0; reg [7:0] tdata; wire tbusy; wire tline;
    uart_tx ttx(.clk(clk), .start(tstart), .data(tdata), .tx(tline), .busy(tbusy));
    assign rxin = tline;
    task send(input [8*24-1:0] s); integer k; begin
        for (k = 23; k >= 0; k = k - 1) if (s[8*k +: 8] != 0) begin
            @(negedge clk); tdata = s[8*k +: 8]; tstart = 1; @(negedge clk); tstart = 0; wait(!tbusy);
        end
    end endtask
    integer prompts = 0;
    always @(posedge clk) if (v) begin
        $write("%c", d);
        if (d == "#" || d == "?") begin $display("\nFAIL"); $finish; end
        if (d == ">") begin
            prompts = prompts + 1;
            if (prompts == 4) begin $display("\nPASS"); $finish; end
        end
    end
    initial begin wait(prompts==1); send("seed 1\015rand 10\015"); wait(prompts==3); send("peek 20000000\015"); end
    initial begin #60_000_000 $display("FAIL timeout"); $finish; end
endmodule

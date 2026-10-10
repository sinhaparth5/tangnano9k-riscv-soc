// Runs the real firmware on the SoC, types "help", checks video timing and TMDS encoding,
// and dumps the rendered frame to build/frame.pbm.
`timescale 1ns/1ps
module tb;
    reg clk = 0; always #18.5 clk = ~clk;                 // ~27 MHz
    wire txo, de, hs, vs, pix; wire [5:0] led;
    wire rxin;
    soc #(.HEX("build/fw.hex")) dut(.clk(clk), .pll_lock(1'b1), .btn_s1(1'b1), .uart_rx(rxin), .uart_tx(txo),
                                    .led(led), .vid_de(de), .vid_hs(hs), .vid_vs(vs), .vid_pix(pix));
    integer errors = 0;

    // ---- UART: watch the board's output, type into it ----
    wire v; wire [7:0] d;
    uart_rx mon(.clk(clk), .rx(txo), .valid(v), .data(d));
    reg tstart = 0; reg [7:0] tdata; wire tbusy;
    uart_tx ttx(.clk(clk), .start(tstart), .data(tdata), .tx(rxin), .busy(tbusy));
    task send(input [8*8-1:0] s); integer k; begin
        for (k = 7; k >= 0; k = k - 1) if (s[8*k +: 8] != 0) begin
            @(negedge clk); tdata = s[8*k +: 8]; tstart = 1; @(negedge clk); tstart = 0; wait(!tbusy);
        end
    end endtask
    integer prompts = 0;
    always @(posedge clk) if (v) begin
        $write("%c", d);
        if (d == ">") prompts = prompts + 1;
    end
    initial begin wait(prompts == 1); send("help\015"); end

    // ---- video timing: 858 x 525, hsync 62, vsync 6 lines, all counted in pixel clocks ----
    integer c_hs = 0, c_vs = 0, w_hs = 0, w_vs = 0, n_hs = 0, n_vs = 0, seen_hs = 0, seen_vs = 0;
    reg hs_q = 1, vs_q = 1;
    always @(posedge clk) begin
        hs_q <= hs; vs_q <= vs; c_hs <= c_hs + 1; c_vs <= c_vs + 1;
        if (!hs) w_hs <= w_hs + 1;
        if (!vs) w_vs <= w_vs + 1;
        if (hs_q && !hs) begin
            if (seen_hs >= 2 && c_hs != 858) begin errors = errors + 1; $display("BAD hs period %0d", c_hs); end
            c_hs <= 1; seen_hs <= seen_hs + 1;
        end
        if (!hs_q && hs && seen_hs >= 2 && w_hs != 62) begin errors = errors + 1; $display("BAD hs width %0d", w_hs); end
        if (hs) w_hs <= 0;
        if (vs_q && !vs) begin
            if (seen_vs >= 1 && c_vs != 858*525) begin errors = errors + 1; $display("BAD vs period %0d", c_vs); end
            c_vs <= 1; seen_vs <= seen_vs + 1;
        end
        if (!vs_q && vs && seen_vs >= 1 && w_vs != 858*6) begin errors = errors + 1; $display("BAD vs width %0d", w_vs); end
        if (vs) w_vs <= 0;
    end

    // ---- capture one frame after the second prompt (help finished) ----
    reg [0:0] frame [0:720*480-1];
    integer px = 0, f, grabbing = 0, done = 0;
    always @(posedge clk) begin
        if (!vs_q && vs && prompts >= 2 && !grabbing && !done) begin grabbing = 1; px = 0; end   // vsync end = frame start
        else if (grabbing && vs_q && !vs) begin                                                    // next vsync start = frame over
            f = $fopen("build/frame.pbm", "w");
            $fwrite(f, "P1\n720 480\n");
            for (px = 0; px < 720*480; px = px + 1) $fwrite(f, "%0d%s", ~frame[px], (px % 720 == 719) ? "\n" : " ");
            $fclose(f); grabbing = 0; done = 1;
        end
        if (grabbing && de && px < 720*480) begin frame[px] <= pix; px = px + 1; end
    end

    // ---- TMDS: random bytes -> encode -> decode must match, running disparity stays small ----
    reg [7:0] data = 8'h5a; reg [7:0] data_d = 0; wire [9:0] q;
    tmds_enc enc(.clk(clk), .d(data), .c(2'b00), .de(1'b1), .q(q));
    function [7:0] decode(input [9:0] t); reg [7:0] x; begin
        x = t[9] ? ~t[7:0] : t[7:0];
        decode[0] = x[0];
        decode[7:1] = t[8] ? (x[7:1] ^ x[6:0]) : ~(x[7:1] ^ x[6:0]);
    end endfunction
    integer ones = 0, disp = 0, maxd = 0, tm = 0, i;
    always @(posedge clk) begin
        data <= {data[6:0], data[7] ^ data[5] ^ data[4] ^ data[3]} ^ {data[0], 7'b0};   // pseudo-random
        data_d <= data;
        if (tm > 3) begin
            if (decode(q) !== data_d) begin errors = errors + 1; $display("BAD tmds %b -> %h, want %h", q, decode(q), data_d); end
            ones = 0; for (i = 0; i < 10; i = i + 1) ones = ones + q[i];
            disp = disp + 2*ones - 10;
            if (disp > maxd) maxd = disp; if (-disp > maxd) maxd = -disp;
        end
        tm <= tm + 1;
    end

    // ---- finish ----
    always @(posedge clk) if (done) begin
        if (dut.vid.cram[90] !== "[" || dut.vid.cram[91] !== "S" || dut.vid.cram[92] !== "o") begin errors = errors + 1; $display("BAD char RAM row 1: %c%c%c", dut.vid.cram[90], dut.vid.cram[91], dut.vid.cram[92]); end
        if (maxd > 10) begin errors = errors + 1; $display("BAD tmds disparity %0d", maxd); end
        if (de === 1'bx || seen_vs < 2) begin errors = errors + 1; $display("BAD video not running"); end
        $display("\n%s (errors=%0d, tmds max disparity=%0d, frames seen=%0d)", errors ? "FAIL" : "PASS", errors, maxd, seen_vs);
        $finish;
    end
    initial begin #200_000_000 $display("FAIL timeout (prompts=%0d)", prompts); $finish; end
endmodule
